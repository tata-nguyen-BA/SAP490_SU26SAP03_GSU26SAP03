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

Backend ABAP cung cấp 4 OData V4 service: 3 service nghiệp vụ (upload) + 1 service
báo cáo/KPI dùng chung cho cả 3 module:

| Module | Chức năng | OData Service | Đường post thật |
|--------|-----------|---------------|------|
| **ZFI** | Upload Chứng từ Kế toán (FI Journal Entry) | `ZFI_UI_ZUP_FIDOC_O4` | SOAP loopback (`ZFI_CL_FIDOC_POSTING_SRV::POST_SOAP`, chạy ngoài RAP modify-phase) |
| **ZPP** | Upload Lệnh Sản xuất (PP Production Order) | `ZPP_UI_ZUPLSX_O4` | RFC tự viết `ZPP_RFC_CREATE_PRODORD` (nhóm hàm `ZPP_FG_ZUPLSX`) → bên trong gọi `BAPI_PRODORD_CREATE` |
| **ZIH** | Upload Phiếu Nhập kho theo PO (MM Goods Receipt) | `ZMM_UI_POGR_O4` | `BAPI_GOODSMVT_CREATE` (per-item) + APJ background job |
| **Báo cáo/KPI** | Analytics gộp FI+PP+GR cho app `zup_rpt` | `ZUP_UI_RPT_O4` | — (chỉ đọc, không post) |

Cả 3 action upload (`uploadFromExcel`/`uploadExcel`) đều kiểm tra quyền qua
`ZIH_CL_AUTH::CHECK` (bảng `ZIH_TB_AUTH_USER`, theo email SSO + module + activity)
trước khi xử lý — xem mục "Authorization" bên dưới.

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
│              Package ZPK_GSU26SAP03 (package gốc)      │
│                                                        │
│  Class nghiệp vụ FI (nằm trực tiếp trong package gốc, │
│  KHÔNG nằm trong ZFI_PK_FIDOC_LEGACY)                  │
│  ├── ZFI_CL_FIDOC_VALIDATOR / MAPPER / POSTING_SRV /   │
│  │   LOG_SRV                parse + validate + SOAP    │
│  ├── ZFI_I_DIS_UP / ZFI_IF_FIDOC_TYPES  CDS + Types    │
│  ├── ZBP_FI_I_DIS_UP        RAP Behavior Implementation│
│  └── ZFI_UI_ZUP_FIDOC_O4    OData V4 Service Binding   │
│                                                        │
│  ├─ ZFI_PK_FIDOC_LEGACY (sub-package)                  │
│  │  └── ZFI_CL_FIDOC_HTTP_WRAP   SOAP HTTP client      │
│                                                        │
│  ├─ ZPP_PK_ZUPLSX (sub-package)                        │
│  │  ├── ZPP_CL_ZUPLSX_VALIDATOR / POSTING_SRV          │
│  │  ├── ZPP_RFC_CREATE_PRODORD  RFC → BAPI_PRODORD_CREATE│
│  │  ├── ZPP_I/C_ZUPLSX      CDS Interface + Projection │
│  │  ├── ZBP_PP_I_ZUPLSX     RAP Behavior Implementation│
│  │  └── ZPP_UI_ZUPLSX_O4    OData V4 Service Binding   │
│                                                        │
│  ├─ ZIH_POGR (sub-package, module chính)               │
│  │  ├── ZMM_CL_GR_SRV       parse + validate + APJ     │
│  │  ├── ZIH_CL_AUTH         permission check dùng chung│
│  │  ├── ZMM_I/C_GR_H/I      CDS Interface + Projection │
│  │  ├── ZMM_CL_BP_GR        RAP Behavior (+ getMyAuth) │
│  │  ├── ZMM_UI_POGR_O4      OData V4 Service Binding   │
│  │  └── ZMM_CL_JOB_POST_GR  APJ Background Job         │
│                                                        │
│  └─ ZPK_ZUP_RPT (sub-package, báo cáo/KPI)              │
│     ├── ZUP_C_UPLOAD_KPI    CDS UNION GR+FI+PP+lỗi     │
│     ├── ZUP_C_FIUPLOAD_RPT / PPUPLOAD_RPT / FI_ITEM    │
│     └── ZUP_UI_RPT_O4       OData V4 Service Binding   │
└────────────────────────────────────────────────────────┘
```

---

## Cấu trúc Repository

```
📦 SAP490_SU26SAP03_GSU26SAP03/  (package gốc ZPK_GSU26SAP03, 64 object)
 ├── (class nghiệp vụ FI nằm trực tiếp ở đây, KHÔNG có sub-package riêng)
 │   ├── ZFI_CL_FIDOC_VALIDATOR / MAPPER / POSTING_SRV / LOG_SRV
 │   ├── ZBP_FI_I_DIS_UP, ZFI_IF_FIDOC_TYPES
 │   ├── ZFI_I_DIS_UP / ZFI_I_DIS_UP_I (CDS), ZFI_TB_UPLOAD / _I (bảng)
 │   └── ZFI_UI_ZUP_FIDOC_O4 (SRVB)
 ├── ZFI_PK_FIDOC_LEGACY/          # chỉ còn 1 object
 │   └── ZFI_CL_FIDOC_HTTP_WRAP    # SOAP HTTP client (cl_http_client)
 ├── ZPP_PK_ZUPLSX/                 # 26 object
 │   ├── CDS/                     # ZPP_I_ZUPLSX, ZPP_C_ZUPLSX + value help CDS
 │   ├── BDEF/                    # Behavior Definition ZPP_I_ZUPLSX
 │   ├── CLASS/                   # ZPP_CL_ZUPLSX_VALIDATOR, _POSTING_SRV, ZBP_PP_I_ZUPLSX
 │   ├── FUGR/ZPP_FG_ZUPLSX       # chứa RFC ZPP_RFC_CREATE_PRODORD (gọi BAPI_PRODORD_CREATE)
 │   └── SRVD_SRVB/               # ZPP_UI_ZUPLSX (SRVD + SRVB)
 ├── ZIH_POGR/                     # 52 object, module chính
 │   ├── CORE/                    # Domain, Data Element, Table, Enqueue, Auth
 │   │   ├── DOMA/                # ZIH_DO_PROCESS_ID, ZIH_DO_UPLOAD_STATUS, ZMM_DO_GR_NUMBER ...
 │   │   ├── DTEL/                # ZIH_DE_BATCH_ID, ZMM_DE_GR_NUMBER ...
 │   │   ├── TABL/                # ZMM_TB_GR_H, ZMM_TB_GR_I, ZIH_TB_AUTH_USER, ZIH_TB_MAP_H/I, ZIH_TB_BATCH
 │   │   └── ENQU/                # EZMM_GR_UPLOAD
 │   ├── SERVICE/                 # ZMM_CL_GR_SRV, ZIH_CL_AUTH, ZIH_CL_SEED_AUTH
 │   ├── CDS/                     # ZMM_I/C_GR_H, ZMM_I/C_GR_I, ZMM_I_PO_LOOKUP,
 │   │   │                        # ZD_GRUPLOADPARAM, ZD_GR_UPLOAD_RESULT,
 │   │   │                        # ZD_GR_AUTH_PARAM, ZD_GR_MY_AUTH, ZD_GR_RETRY_PARAM (abstract entities)
 │   │   └── *.ddlx               # Metadata extensions
 │   ├── BDEF_BP/                 # BDEF (uploadExcel/retryPost/getMyAuth) + ZMM_CL_BP_GR
 │   ├── SRVD_SRVB/                # ZMM_UI_POGR_O4
 │   └── JOB/                     # ZMM_CL_JOB_POST_GR, ZMM_AJC_POST_GR (JOBC), ZMM_AJT_POST_GR (JOBT)
 ├── ZPK_ZUP_RPT/                  # 15 object — CDS báo cáo/KPI dùng chung cho app zup_rpt
 │   ├── ZUP_C_UPLOAD_KPI          # UNION ALL GR+FI+PP+ztb_upload_err, có ProcessingSeconds
 │   ├── ZUP_C_FIUPLOAD_RPT, ZUP_C_PPUPLOAD_RPT, ZUP_C_FIUPLOAD_ITEM, ZUP_P_FIUPLOAD_ITEMCNT
 │   └── ZUP_UI_RPT_O4             # SRVD ZUP_UI_RPT + SRVB — expose FIUploadReport/PPUploadReport/FIUploadItem/UploadKPI
 └── README.md
```

---

## Mô tả các Package

### Class nghiệp vụ FI — FI Journal Entry Upload

Class chính (`ZFI_CL_FIDOC_VALIDATOR`/`MAPPER`/`POSTING_SRV`/`LOG_SRV`) nằm **trực
tiếp trong package gốc** `ZPK_GSU26SAP03`, không nằm trong sub-package
`ZFI_PK_FIDOC_LEGACY` (sub-package đó giờ chỉ còn giữ 1 class:
`ZFI_CL_FIDOC_HTTP_WRAP`, HTTP client cho đường post SOAP). Tải lên chứng từ kế
toán từ Excel, hỗ trợ 88 cột cấu hình, validate trước khi post, log kết quả từng
dòng.

- **Action**: `uploadFromExcel` (bound action trên `ZFI_I_DIS_UP`, OData V4)
- **Check quyền**: `ZIH_CL_AUTH::CHECK(process=FI, actvt=01)` ngay sau parse JSON
- **Result**: per-row `[0..*]` — kết quả đồng bộ, hiển thị ngay sau khi gọi
- **Post thật**: `ZFI_CL_FIDOC_POSTING_SRV::POST_SOAP` — SOAP loopback qua
  `ZFI_CL_FIDOC_HTTP_WRAP::SEND_SOAP` (`cl_http_client=>create_by_destination`),
  chạy **ngoài** RAP modify-phase (RAP cấm `MODIFY ENTITIES` của business object
  khác ngay trong action handler, nên không dùng EML `I_JOURNALENTRYTP` trực tiếp
  ở đây dù class có sẵn method `POST`/`SIMULATE` theo hướng EML)

### ZPP\_PK\_ZUPLSX — PP Production Order Upload

Tạo hàng loạt Lệnh Sản xuất từ Excel. Validate ngày DD/MM/YYYY → YYYYMMDD, retry dòng lỗi.

- **Action**: `uploadFromExcel` (bound action, OData V4)
- **Check quyền**: `ZIH_CL_AUTH::CHECK(process=PP, actvt=01)` ngay sau parse JSON
- **Result**: per-row `[0..*]` — kết quả đồng bộ
- **Post thật**: `ZPP_CL_ZUPLSX_POSTING_SRV::POST` gọi RFC tự viết
  `ZPP_RFC_CREATE_PRODORD` (function group `ZPP_FG_ZUPLSX`) — RFC này mới gọi
  `BAPI_PRODORD_CREATE` thật, chạy LUW riêng ngoài RAP framework

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

`ZIH_TB_MAP_H`/`ZIH_TB_MAP_I` (mapping engine) tồn tại nhưng **chưa được code nào
đọc** — `mapping_id="POGR001"` FE gửi lên hiện là tham số chết.

Authorization thì **có seed thật**, qua class `ZIH_CL_SEED_AUTH`
(`IF_OO_ADT_CLASSRUN~MAIN`, chạy 1 lần trong ADT) insert vào `ZIH_TB_AUTH_USER`
theo đúng cấu trúc thật (`user_email` + `process_id` FI/PP/GR + `actvt` 01=post/
03=view), ví dụ tương đương:

```abap
INSERT zih_tb_auth_user FROM TABLE @( VALUE #(
  ( user_email = 'user@example.com' process_id = 'GR' actvt = '01' )
  ( user_email = 'user@example.com' process_id = 'GR' actvt = '03' )
) ).
COMMIT WORK.
```

---

## Authorization

Cả 3 action upload (`ZBP_FI_I_DIS_UP::uploadFromExcel`,
`ZBP_PP_I_ZUPLSX::uploadFromExcel`, `ZMM_CL_GR_SRV::upload_excel`) và action
`ZMM_CL_BP_GR::retry_post` đều gọi `ZIH_CL_AUTH::CHECK( iv_email, iv_process_id,
iv_actvt )` trước khi xử lý — `SELECT SINGLE` thật trên `ZIH_TB_AUTH_USER`, không
tìm thấy dòng khớp thì trả message lỗi rõ ràng và chặn action. Email lấy từ
`useremail`/`user_email` trong payload JSON mà FE gửi lên (đọc từ SSO Work Zone
qua `sap.ushell.Container` `UserInfo` service).

FE còn gọi thêm action `getMyAuth` (khai trên `ZMM_I_GR_H`, implement trong
`ZMM_CL_BP_GR`/`lhc_gr_upload::get_my_auth`) để lấy `can_upload_fi/pp/gr` cho
riêng mục đích ẩn/hiện nút Check/Post trên UI. **Lưu ý:** BDEF projection
`ZMM_C_GR_H` (cái thật sự expose qua `ZMM_UI_POGR_O4`) hiện chỉ có `use action
uploadExcel;` và `use action retryPost;`, **thiếu `use action getMyAuth;`** — nên
action này nhiều khả năng không nằm trong `$metadata` thật và lời gọi từ FE có thể
lỗi ở runtime. Việc chặn server-side (trong các action handler) không phụ thuộc
gap này.

Bảng `ZIH_TB_AUTH_USER` không dùng `AUTHORITY-CHECK OBJECT` chuẩn của SAP — code
mẫu theo hướng đó (object `Z_UPLOAD`) có mặt trong cả 3 handler nhưng đang bị
comment out, hướng đã chọn là bảng tự viết.

## Package báo cáo/KPI — `ZPK_ZUP_RPT`

Sub-package riêng cho phần Analytics, tách khỏi CDS nghiệp vụ chính, phục vụ app
FE `zup_rpt`:

| Object | Vai trò |
|---|---|
| `ZUP_C_UPLOAD_KPI` | CDS `UNION ALL` 4 nguồn: `zmm_tb_gr_h` (GR), `zfi_tb_upload` (FI), `zpp_tb_zuplsx` (PP), `ztb_upload_err` (lỗi upload FI/PP). Trường `ProcessingSeconds` chỉ tính cho GR (`utcl_seconds_between(created_at, last_changed_at)` khi status S/E) — đây là nguồn cho KPI "thời gian xử lý". |
| `ZUP_C_FIUPLOAD_RPT`, `ZUP_C_PPUPLOAD_RPT`, `ZUP_C_FIUPLOAD_ITEM`, `ZUP_P_FIUPLOAD_ITEMCNT` | CDS báo cáo riêng cho trang FiRpt/PpRpt. GR không có CDS báo cáo riêng — trang GrRpt đọc thẳng entity `GrUpload`/`GrItem` của `ZMM_UI_POGR_O4`. |
| `ZUP_UI_RPT` (SRVD) / `ZUP_UI_RPT_O4` (SRVB) | Expose `FIUploadReport`, `PPUploadReport`, `FIUploadItem`, `UploadKPI` — service `mainService` mà app `zup_rpt` dùng cho các trang FiRpt/PpRpt/KpiRpt. |

---

## Công nghệ sử dụng

| Layer | Technology |
|-------|------------|
| Core | ABAP RAP — managed BDEF, unmanaged bound actions |
| OData | OData V4 — Service Definition (SRVD) + Service Binding (SRVB) |
| CDS | Core Data Services — Interface + Projection + Abstract entities |
| Async | SAP Application Job Framework (APJ) — JOBC + JOBT |
| BAPI/RFC thật | `BAPI_GOODSMVT_CREATE` (GR, gọi trực tiếp), `BAPI_PRODORD_CREATE` (PP, qua RFC tự viết `ZPP_RFC_CREATE_PRODORD`), FI post qua SOAP loopback (`ZFI_CL_FIDOC_HTTP_WRAP`), không gọi `BAPI_ACC_DOCUMENT_POST` trực tiếp |
| Authorization | Bảng tự viết `ZIH_TB_AUTH_USER` + class `ZIH_CL_AUTH`, check theo email SSO — không dùng `AUTHORITY-CHECK OBJECT` chuẩn |
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
5. Activate SRVB cho từng service (ZFI_UI_ZUP_FIDOC_O4, ZPP_UI_ZUPLSX_O4, ZMM_UI_POGR_O4, ZUP_UI_RPT_O4)
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
