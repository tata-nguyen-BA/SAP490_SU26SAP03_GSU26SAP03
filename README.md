# SAP BTP Integration Hub — ZPK_GSU26SAP03

> **Đồ án tốt nghiệp** — Xây dựng nền tảng tích hợp tải lên chứng từ hàng loạt từ Excel lên SAP S/4HANA thông qua giao diện Fiori trên SAP Business Technology Platform.

---

## Tổng quan

Hệ thống cho phép người dùng kế toán / sản xuất / kho vận tải lên hàng loạt chứng từ SAP từ file Excel mà không cần vào transaction SAP GUI, gồm 3 module nghiệp vụ:

| Module | Chức năng | OData Service |
|--------|-----------|---------------|
| **ZFI** | Upload Chứng từ Kế toán (FI Journal Entry) | `ZFI_UI_ZUP_FIDOC_O4` |
| **ZPP** | Upload Lệnh Sản xuất (PP Production Order) | `ZPP_UI_ZUPLSX_O4` |
| **ZIH** | Upload Phiếu Nhập kho theo PO (MM Goods Receipt) | `ZMM_UI_POGR_O4` |

---

## Kiến trúc hệ thống

```
┌───────────────────────────────────────────────────────┐
│              SAP Business Technology Platform          │
│                                                       │
│  ┌─────────────────┐      ┌────────────────────────┐  │
│  │  zfi_pk_zup      │      │  zup_rpt               │  │
│  │  Upload Hub      │      │  Analytics Hub         │  │
│  │  FI · PP · GR   │      │  FI · PP · GR Reports  │  │
│  └────────┬─────────┘      └──────────┬─────────────┘  │
│           │      OData V4 / Destination│               │
└───────────┼──────────────────────────┼───────────────┘
            │   BTP Connectivity        │
┌───────────┼──────────────────────────┼───────────────┐
│           ▼   SAP S/4HANA On-Premise ▼               │
│   Package ZPK_GSU26SAP03                             │
│   ├── ZFI_PK_FIDOC_LEGACY  →  BAPI_ACC_DOCUMENT_POST│
│   ├── ZPP_PK_ZUPLSX         →  BAPI_PRODORD_CREATE  │
│   └── ZIH_POGR              →  BAPI_GOODSMVT_CREATE │
│                                  + APJ Background Job│
└──────────────────────────────────────────────────────┘
```

---

## Cấu trúc Repository

```
📦 sap-btp-integration-hub/
 ├── backend/
 │   ├── ZFI_PK_FIDOC_LEGACY/     # ABAP objects — FI Upload
 │   ├── ZPP_PK_ZUPLSX/           # ABAP objects — PP Upload
 │   └── ZIH_POGR/                # ABAP objects — GR Upload (32 objects)
 ├── frontend/
 │   ├── zfi_pk_zup/              # Upload Hub (FI + PP + GR)
 │   └── zup_rpt/                 # Analytics Hub (FI + PP + GR)
 └── README.md
```

---

## Frontend Applications

### 1. `zfi_pk_zup` — Upload Hub

Tải lên chứng từ hàng loạt từ file Excel cho 3 luồng nghiệp vụ.

**Tính năng:**
- **FI Tab**: 88 cột cấu hình, check validate / post lên SAP, xem lịch sử file
- **PP Tab**: Validate ngày DD/MM/YYYY, retry dòng lỗi, kết quả Production Order
- **GR Tab**: Group nhiều dòng theo GR Number → staging → background job → monitor status

**Chạy local:**

```bash
cd frontend/zfi_pk_zup
npm install
npm start
# → http://localhost:8080
```

---

### 2. `zup_rpt` — Analytics Hub

Báo cáo và phân tích dữ liệu đã upload.

**Tính năng:**
- Filter theo Date Range, Status, CreatedBy
- KPI tiles tính client-side (Total / Success / Error / Pending)
- Chart phân tích theo chiều (Document Type / Plant / Month / Status)
- Xuất Excel báo cáo (sheet Summary + Data chi tiết)

**Chạy local:**

```bash
cd frontend/zup_rpt
npm install
npm start
```

---

## Deploy lên BTP & SAP Work Zone

### Bước 1 — Build ứng dụng

```bash
# Cho từng app
cd frontend/zfi_pk_zup
npm run build

cd frontend/zup_rpt
npm run build
```

### Bước 2 — Deploy lên HTML5 Application Repository (BTP)

Sử dụng Fiori Tools hoặc MTA deploy:

```bash
# Login vào BTP Cloud Foundry
cf login -a https://api.cf.<region>.hana.ondemand.com \
  -o <your-org> -s <your-space>

# Deploy từng app (nếu dùng cf push + manifest.yml)
cf push zfi-pk-zup  -f frontend/zfi_pk_zup/manifest.yml
cf push zup-rpt     -f frontend/zup_rpt/manifest.yml

# Hoặc dùng MTA (nếu có mta.yaml)
mbt build
cf deploy mta_archives/*.mtar
```

> Nếu dùng **SAP Fiori Tools** trong VS Code: chọn `Fiori: Deploy Application` → chọn BTP target → chọn space.

### Bước 3 — Thêm vào SAP Work Zone

1. Mở **SAP Work Zone** (hay Launchpad Service) trên BTP cockpit
2. Vào **Provider Manager** → refresh HTML5 Apps
3. Vào **Content Manager** → **Content Explorer** → tìm `zfi_pk_zup` và `zup_rpt`
4. Thêm vào **My Content** → gán vào **Role** phù hợp
5. Vào **Site Manager** → thêm vào **Group** trên Launchpad site
6. Publish site

### Bước 4 — Cấu hình Destination (BTP Connectivity)

Tạo destination trong BTP cockpit trỏ vào S/4HANA on-premise:

| Property | Giá trị |
|----------|---------|
| Name | `S4H_BACKEND` |
| Type | HTTP |
| URL | `https://<your-s4hana-host>:<port>` |
| Authentication | BasicAuthentication (hoặc PrincipalPropagation) |
| Additional: `sap-client` | `<client>` |
| Additional: `WebIDEEnabled` | `true` |
| Additional: `HTML5.DynamicDestination` | `true` |

---

## Backend — ZIH_POGR (Goods Receipt Upload)

Module mới xây dựng hoàn toàn theo ABAP RAP với APJ background job.

### Các Phase triển khai

| Phase | Nội dung | Số objects |
|-------|----------|------------|
| 1 — Foundation | Domain, Data Element, Table staging (ZMM_TB_GR_H/I), Enqueue, Auth table | 13 |
| 2 — Service Class | `ZMM_CL_GR_SRV` — parse Excel JSON, validate PO, BAPI, schedule job | 1 |
| 3 — CDS Views | Interface, Projection, Abstract entities, Metadata extensions | 9 |
| 4 — BDEF + Service | BDEF managed, BP class, SRVD, SRVB (OData V4 UI) | 5 |
| 5 — Background Job | `ZMM_CL_JOB_POST_GR`, JOBC `ZMM_AJC_POST_GR`, JOBT `ZMM_AJT_POST_GR` | 3 |
| 6 — Analytics | KPI CDS view, Projection + update SRVD | 2 + update |

### Luồng xử lý GR Upload

```
FE: Excel → group theo GR Number → JSON payload
  ↓  OData V4 Action: GrUpload/uploadExcel
     { payload_json, mapping_id="POGR001", testmode }

BE: ZMM_CL_BP_GR → ZMM_CL_GR_SRV::upload_excel
    ├── parse_payload()    → JSON → ABAP structures
    ├── validate()         → check EKBE open quantity
    ├── postgr(test=true)  → BAPI dry run
    ├── SAVE staging       → ZMM_TB_GR_H / ZMM_TB_GR_I (status = R)
    └── schedule_job()     → cl_apj_rt_api::schedule_job (ZMM_AJT_POST_GR)

JOB (background): ZMM_CL_JOB_POST_GR::execute
    ├── BAPI_GOODSMVT_CREATE (movement type 101)
    ├── COMMIT WORK AND WAIT
    └── UPDATE ZMM_TB_GR_H → status S/E + material_document
```

### Initial Data Setup

Sau khi activate Phase 1, chạy ABAP report hoặc SE16 để insert:

```abap
" Mapping config
INSERT INTO zih_tb_map_h VALUES @( VALUE #(
  mapping_id   = 'POGR001'
  process_id   = 'POGR'
  mapping_name = 'PO GR Standard'
  file_type    = 'XLSX'
  is_active    = abap_true ) ).

" User authorization
INSERT INTO zih_tb_auth_user VALUES @( VALUE #(
  username   = sy-uname
  process_id = 'POGR'
  actvt      = '16' ) ).

COMMIT WORK.
```

---

## Công nghệ sử dụng

| Layer | Technology |
|-------|------------|
| Backend | ABAP RAP (managed BDEF, unmanaged actions) |
| OData | OData V4 — bound Actions, Compositions |
| Async | SAP Application Job Framework (APJ) |
| BAPI | `BAPI_GOODSMVT_CREATE`, `BAPI_PRODORD_CREATE`, `BAPI_ACC_DOCUMENT_POST` |
| Frontend | SAP UI5 (Freestyle) — IconTabBar, OData V4 model |
| Excel parsing | SheetJS (`xlsx.bundle.js`) — phía client |
| Chart | SVG chart tự vẽ, client-side aggregation |
| Deploy | SAP BTP Cloud Foundry, HTML5 Application Repository |
| Launchpad | SAP Work Zone (Launchpad Service Standard) |

---

## Yêu cầu môi trường

### Backend (ABAP)
- SAP S/4HANA On-Premise (ABAP 7.56+)
- Eclipse ADT với SAP Fiori Tools plugin
- Application Job Framework (APJ) — kích hoạt `/IWFND/MAINT_SERVICE` và `APJ_RT_API`

### Frontend (Node.js)
```bash
node --version   # >= 18
npm install -g @sap/ux-ui5-tooling
```

### BTP
- SAP BTP account (trial hoặc enterprise)
- Cloud Foundry environment
- HTML5 Application Repository service
- Connectivity + Destination service
- SAP Work Zone Standard / Advanced

---

## Bảo mật & `.gitignore`

Không commit các file sau lên git:

```
.env
cookies*.txt
.mcp.json
.vsp.json
*.local.*
node_modules/
dist/
```

Không đưa vào file tracked: username/password SAP thật, hostname hệ thống thật, transport number thật (DEVK*, R*K*, D*K*).

---

## Tác giả

**Đồ án tốt nghiệp — Hệ thống Tích hợp SAP BTP**

- Nhóm: SU26SAP03_GSU26SAP03
- GVHD: Nguyễn Thị Cẩm Hương
- Trường: Đại học FPT
- Năm: 2026
