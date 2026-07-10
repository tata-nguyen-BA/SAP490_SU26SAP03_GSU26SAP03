# SAP BTP Integration Hub — Backend (ZPK_GSU26SAP03)

> **Đồ án tốt nghiệp** — ABAP Backend cho hệ thống tích hợp tải lên chứng từ SAP hàng loạt từ Excel, xây dựng trên SAP S/4HANA với kiến trúc ABAP RAP + OData V4.

[![BE Repo](https://img.shields.io/badge/repo-Backend%20ABAP-0553CE?logo=sap)](https://github.com/tata-nguyen-BA/SAP490_SU26SAP03_GSU26SAP03)
[![FE Repo](https://img.shields.io/badge/repo-Frontend%20Fiori-2563EB?logo=sap)](https://github.com/tata-nguyen-BA/SAP490_SU26SAP03_GSU26SAP03_FE)

---

## Liên kết Repository

| Repo | Mô tả | Link |
|------|-------|------|
| **Backend (repo này)** | ABAP objects — ZFI, ZPP, ZIH_POGR | [SAP490_SU26SAP03_GSU26SAP03](https://github.com/tata-nguyen-BA/SAP490_SU26SAP03_GSU26SAP03) |
| **Frontend** | SAP UI5 Fiori apps — zfi_pk_zup, zup_rpt | [SAP490_SU26SAP03_GSU26SAP03_FE](https://github.com/tata-nguyen-BA/SAP490_SU26SAP03_GSU26SAP03_FE) |

---

## Tổng quan

Backend ABAP cung cấp 3 OData V4 service cho phép tải lên chứng từ SAP hàng loạt:

| Module | Chức năng | OData Service | BAPI |
|--------|-----------|---------------|------|
| **ZFI** | Upload Chứng từ Kế toán (FI Journal Entry) | `ZFI_UI_ZUP_FIDOC_O4` | `BAPI_ACC_DOCUMENT_POST` |
| **ZPP** | Upload Lệnh Sản xuất (PP Production Order) | `ZPP_UI_ZUPLSX_O4` | `BAPI_PRODORD_CREATE` |
| **ZIH** | Upload Phiếu Nhập kho theo PO (MM Goods Receipt) | `ZMM_UI_POGR_O4` | `BAPI_GOODSMVT_CREATE` + APJ |

---

## Kiến trúc hệ thống

```
┌───────────────────────────────────────────────────────┐
│              SAP Business Technology Platform          │
│  zfi_pk_zup (Upload Hub)  │  zup_rpt (Analytics Hub)  │
│           OData V4 / BTP Connectivity Destination      │
└───────────────────────────────────────────────────────┘
                           │
┌──────────────────────────▼────────────────────────────┐
│              SAP S/4HANA On-Premise                    │
│              Package ZPK_GSU26SAP03                    │
│                                                        │
│  ZFI_PK_FIDOC_LEGACY                                   │
│  ├── ZFI_CL_FIDOC_SRV      parse + validate + SOAP    │
│  ├── ZFI_I/C_UPLOAD_LOG    CDS Interface + Projection  │
│  ├── ZBP_FI_I_DIS_UP       RAP Behavior Implementation │
│  └── ZFI_UI_ZUP_FIDOC_O4   OData V4 Service Binding   │
│                                                        │
│  ZPP_PK_ZUPLSX                                         │
│  ├── ZPP_CL_ZUPLSX_SRV     parse + validate + BAPI    │
│  ├── ZPP_I/C_ZUPLSX        CDS Interface + Projection  │
│  ├── ZBP_PP_I_ZUPLSX       RAP Behavior Implementation │
│  └── ZPP_UI_ZUPLSX_O4      OData V4 Service Binding   │
│                                                        │
│  ZIH_POGR  (32 objects mới)                            │
│  ├── ZMM_CL_GR_SRV         parse + validate + APJ     │
│  ├── ZMM_I/C_GR_H/I        CDS Interface + Projection  │
│  ├── ZMM_CL_BP_GR          RAP Behavior Implementation │
│  ├── ZMM_UI_POGR_O4        OData V4 Service Binding   │
│  └── ZMM_CL_JOB_POST_GR    APJ Background Job         │
└────────────────────────────────────────────────────────┘
```

---

## Cấu trúc Repository

```
📦 SAP490_SU26SAP03_GSU26SAP03/
 ├── ZFI_PK_FIDOC_LEGACY/
 │   ├── CDS/                     # ZFI_I_UPLOAD_LOG, ZFI_C_UPLOAD_LOG
 │   ├── BDEF/                    # Behavior Definition ZFI_I_DIS_UP
 │   ├── CLASS/                   # ZFI_CL_FIDOC_SRV, ZBP_FI_I_DIS_UP
 │   └── SRVD_SRVB/               # ZFI_UI_ZUP_FIDOC (SRVD + SRVB)
 ├── ZPP_PK_ZUPLSX/
 │   ├── CDS/                     # ZPP_I_ZUPLSX, ZPP_C_ZUPLSX
 │   ├── BDEF/                    # Behavior Definition ZPP_I_ZUPLSX
 │   ├── CLASS/                   # ZPP_CL_ZUPLSX_SRV, ZBP_PP_I_ZUPLSX
 │   └── SRVD_SRVB/               # ZPP_UI_ZUPLSX (SRVD + SRVB)
 ├── ZIH_POGR/
 │   ├── CORE/                    # Domain, Data Element, Table, Enqueue, Auth
 │   │   ├── DOMA/                # ZMM_D_GR_STATUS, ZMM_D_PROCESS_ID ...
 │   │   ├── DTEL/                # ZMM_E_GR_NUMBER, ZMM_E_BATCH_ID ...
 │   │   ├── TABL/                # ZMM_TB_GR_H, ZMM_TB_GR_I, ZIH_TB_MAP_H ...
 │   │   └── FUGR/                # ZMM_EN_GR_H (Enqueue function group)
 │   ├── SERVICE/                 # ZMM_CL_GR_SRV (Phase 2)
 │   ├── CDS/                     # 9 CDS objects (Phase 3)
 │   │   ├── ZMM_I_GR_H.ddls      # Interface header
 │   │   ├── ZMM_I_GR_I.ddls      # Interface item
 │   │   ├── ZMM_C_GR_H.ddls      # Projection header
 │   │   ├── ZMM_C_GR_I.ddls      # Projection item
 │   │   ├── ZMM_I_PO_LOOKUP.ddls # PO validation view
 │   │   └── *.ddlx               # Metadata extensions
 │   ├── BDEF_BP/                 # BDEF + ZMM_CL_BP_GR (Phase 4)
 │   ├── SRVD_SRVB/               # ZMM_UI_POGR_O4 (Phase 4)
 │   ├── JOB/                     # ZMM_CL_JOB_POST_GR, JOBC, JOBT (Phase 5)
 │   └── KPI/                     # ZMM_I_GR_KPI, ZMM_C_GR_KPI (Phase 6)
 └── README.md
```

---

## Mô tả các Package

### ZFI\_PK\_FIDOC\_LEGACY — FI Journal Entry Upload

Tải lên chứng từ kế toán từ Excel. Hỗ trợ 88 cột cấu hình, validate trước khi post, log kết quả từng dòng.

- **Action**: `uploadExcel` (bound action, OData V4)
- **Result**: per-row `[0..*]` — kết quả đồng bộ, hiển thị ngay sau khi gọi
- **BAPI**: `BAPI_ACC_DOCUMENT_POST` (qua SOAP RFC hoặc direct call)

### ZPP\_PK\_ZUPLSX — PP Production Order Upload

Tạo hàng loạt Lệnh Sản xuất từ Excel. Validate ngày DD/MM/YYYY → YYYYMMDD, retry dòng lỗi.

- **Action**: `uploadExcel` (bound action, OData V4)
- **Result**: per-row `[0..*]` — kết quả đồng bộ
- **BAPI**: `BAPI_PRODORD_CREATE`

### ZIH\_POGR — MM Goods Receipt Upload (32 objects mới)

Module mới hoàn toàn, xây dựng theo ABAP RAP với APJ background job posting.

#### Các Phase triển khai

| Phase | Nội dung | Objects |
|-------|----------|---------|
| **1 — Foundation** | Domain, Data Element, Table staging (`ZMM_TB_GR_H`, `ZMM_TB_GR_I`), Enqueue, Auth table (`ZIH_TB_AUTH_USER`), Mapping tables (`ZIH_TB_MAP_H/I`) | 13 |
| **2 — Service Class** | `ZMM_CL_GR_SRV` — parse Excel JSON, validate PO open qty (EKBE), BAPI dry run, save staging, schedule APJ | 1 |
| **3 — CDS Views** | Interface views, Projection views, Abstract entities, Metadata extensions | 9 |
| **4 — BDEF + Service** | BDEF managed, `ZMM_CL_BP_GR` (RAP handler), `ZMM_UI_POGR_O4` (SRVD + SRVB) | 5 |
| **5 — Background Job** | `ZMM_CL_JOB_POST_GR`, `ZMM_AJC_POST_GR` (JOBC), `ZMM_AJT_POST_GR` (JOBT) | 3 |
| **6 — Analytics** | `ZMM_I_GR_KPI`, `ZMM_C_GR_KPI` + update SRVD | 2 + update |

#### Luồng xử lý GR Upload

```
FE: Excel → group theo GR Number → JSON payload
  ↓  OData V4 Action: GrUpload/uploadExcel
     { payload_json, mapping_id="POGR001", testmode }

BE: ZMM_CL_BP_GR → ZMM_CL_GR_SRV::upload_excel
    ├── parse_payload()    → JSON → ABAP ty_payload_raw
    ├── validate()         → check EKBE open quantity từng PO item
    ├── postgr(test=true)  → BAPI dry run, catch lỗi trước
    ├── SAVE staging       → ZMM_TB_GR_H / ZMM_TB_GR_I (status = R)
    └── schedule_job()     → cl_apj_rt_api::schedule_job (ZMM_AJT_POST_GR)

JOB (background — ngoài RAP LUW):
    ZMM_CL_JOB_POST_GR::execute
    ├── BAPI_GOODSMVT_CREATE (movement type 101, GMCode '01')
    ├── COMMIT WORK AND WAIT
    └── UPDATE ZMM_TB_GR_H → status S/E + material_document
```

- **Result**: `[1]` summary (async) — FE nhận `batch_id`, `total/success/error count`
- FE poll lại History tab để xem kết quả cuối cùng sau khi APJ chạy xong

#### Initial Data Setup

Sau khi activate Phase 1, insert vào các bảng nền:

```abap
" Mapping header
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
| Core | ABAP RAP — managed BDEF, unmanaged bound actions |
| OData | OData V4 — Service Definition (SRVD) + Service Binding (SRVB) |
| CDS | Core Data Services — Interface + Projection + Abstract entities |
| Async | SAP Application Job Framework (APJ) — JOBC + JOBT |
| BAPI | `BAPI_GOODSMVT_CREATE`, `BAPI_PRODORD_CREATE`, `BAPI_ACC_DOCUMENT_POST` |
| Dev Tool | Eclipse ADT, abapGit |

---

## Yêu cầu môi trường

- SAP S/4HANA On-Premise (ABAP 7.56+)
- Eclipse ADT (ABAP Development Tools) với SAP plugin
- abapGit để clone repo vào SAP
- Application Job Framework (APJ) kích hoạt trên hệ thống
- Quyền activate SRVB (OData V4 Service Binding)
- Quyền tạo/publish JOBC và JOBT

---

## Import qua abapGit

```
1. Mở Eclipse ADT → Window → Perspective → ABAP
2. Right-click package ZPK_GSU26SAP03 → abapGit Repositories
3. New → Clone → URL: https://github.com/tata-nguyen-BA/SAP490_SU26SAP03_GSU26SAP03.git
4. Pull → Activate all objects
5. Activate SRVB cho từng service (ZFI_UI_ZUP_FIDOC_O4, ZPP_UI_ZUPLSX_O4, ZMM_UI_POGR_O4)
6. Publish JOBT ZMM_AJT_POST_GR trong Transaction JOBTEMPLATES
```

---

## Bảo mật & `.gitignore`

Không commit vào repo này:

```
.env
*.local.*
*.bak
```

Không đưa vào file tracked: username/password SAP thật, hostname hệ thống thật, transport number thật (`DEVK*`, `R*K*`, `D*K*`), customer namespace thật.

---

## Frontend Repository

Frontend (SAP UI5 Fiori Apps) nằm ở repo riêng:

**[SAP490_SU26SAP03_GSU26SAP03_FE](https://github.com/tata-nguyen-BA/SAP490_SU26SAP03_GSU26SAP03_FE)**

Gồm 2 apps:
- `zfi_pk_zup` — Upload Hub (FI + PP + GR)
- `zup_rpt` — Analytics Hub (FI + PP + GR)

---

## Tác giả

**Đồ án tốt nghiệp — Hệ thống Tích hợp SAP BTP**

- Nhóm: SU26SAP03_GSU26SAP03
- GVHD: Nguyễn Thị Cẩm Hương
- Trường: Đại học FPT
- Năm: 2026
