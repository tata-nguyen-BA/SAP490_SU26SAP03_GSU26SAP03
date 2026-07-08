"! <p class="shorttext synchronized" lang="vn">FI Document Posting – Persistence / Log Service</p>
"! <strong>Thiết kế:</strong>
"! <ul>
"!   <li>Sử dụng Constructor Injection để nhận instance này từ class gọi (ZFI_CL_FIDOC_POSTING_SRV), giúp dễ dàng Mocking khi Unit Test.</li>
"!   <li>Tách biệt tham số IV_IS_UPDATE để làm rõ sự phụ thuộc (Explicit Dependency), thay vì dùng biến ngầm từ God Class.</li>
"!   <li>Sử dụng lệnh MODIFY để hỗ trợ cơ chế Upsert (Cập nhật nếu tồn tại, thêm mới nếu chưa), phù hợp với logic Reposting.</li>
"! </ul>
CLASS zfi_cl_fidoc_log_srv DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! @parameter iv_is_update | TRUE: Cập nhật thông tin thay đổi. FALSE: Ghi nhận hạch toán lần đầu & bật cờ ISPST.
    METHODS save
      IMPORTING is_header         TYPE zfi_if_fidoc_types=>ts_data
                is_accounting_doc TYPE zfi_if_fidoc_types=>ts_accounting_document
                iv_is_update      TYPE abap_bool.

ENDCLASS.



CLASS ZFI_CL_FIDOC_LOG_SRV IMPLEMENTATION.


  METHOD save.
    DATA ls_header_log TYPE zfi_tb_upload.
    DATA ls_item_log   TYPE zfi_tb_upload_i.

    ls_header_log                    = CORRESPONDING #( is_header ).
    ls_header_log-accountingdocument = is_accounting_doc-accountingdocument.
    ls_header_log-fiscalyear         = is_accounting_doc-fiscalyear.

    " Phân biệt logic Audit Trail: Hạch toán mới (PST) vs Cập nhật/Sửa lỗi (UPD)
    IF iv_is_update = abap_true.
      ls_header_log-upd_date = sy-datum.
      ls_header_log-upd_user = sy-uname.
    ELSE.
      ls_header_log-pst_date = sy-datum.
      ls_header_log-pst_user = sy-uname.
      ls_header_log-ispst    = abap_true.
    ENDIF.

    MODIFY zfi_tb_upload FROM @ls_header_log.

    LOOP AT is_header-to_item INTO DATA(ls_item).
      CLEAR ls_item_log.
      ls_item_log          = CORRESPONDING #( ls_item ).
      ls_item_log-filename = ls_header_log-filename.
      ls_item_log-id_doc   = ls_header_log-id_doc.
      MODIFY zfi_tb_upload_i FROM @ls_item_log.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
