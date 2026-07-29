"! <p class="shorttext synchronized" lang="vn">FI Document Posting – Persistence / Log Service</p>
"! <strong>Thiết kế:</strong>
"! <ul>
"!   <li>Sử dụng Constructor Injection để nhận instance này từ class gọi (ZFI_CL_FIDOC_POSTING_SRV), giúp dễ dàng Mocking khi Unit Test.</li>
"!   <li>Tách biệt tham số IV_IS_UPDATE để làm rõ sự phụ thuộc (Explicit Dependency), thay vì dùng biến ngầm từ God Class.</li>
"!   <li>Sử dụng lệnh MODIFY để hỗ trợ cơ chế Upsert (Cập nhật nếu tồn tại, thêm mới nếu chưa), phù hợp với logic Reposting.</li>
"! </ul>
"!
"! <strong>CẢNH BÁO BẢO TRÌ (27/07/2026):</strong> CORRESPONDING khớp field THEO TÊN
"! và bỏ qua âm thầm field không cùng tên. Hiện có 7 chỗ lệch tên giữa
"! ts_item và ZFI_TB_UPLOAD_I, trong đó IDLINE là KEY của bảng nên hậu quả rất nặng
"! (xem method SAVE). Thêm field mới vào ts_item thì phải kiểm tên khớp với bảng.
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



CLASS zfi_cl_fidoc_log_srv IMPLEMENTATION.


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

      "==================================================================
      " FIX QUAN TRỌNG: ts_item đặt tên IDLINE (không gạch dưới) còn bảng
      " log đặt ID_LINE -> CORRESPONDING không nhặt -> ID_LINE luôn = 0.
      " ID_LINE là KEY của bảng, nên MODIFY của mọi dòng trong cùng 1
      " chứng từ đều trúng cùng 1 key (filename, id_doc, 0) và GHI ĐÈ LÊN
      " NHAU -> log chỉ còn giữ DÒNG CUỐI của mỗi chứng từ.
      " Hệ quả trước khi vá: mất dòng bút toán trong log, LineCount và
      " TotalAmountLC của app analytics sai, dialog "Bút toán" chỉ hiện 1 dòng.
      "==================================================================
      ls_item_log-id_line = ls_item-idline.

      " ts_item: INVOICEREFFISCALYEAR / bảng: INVOICEFISCALYEAR -> gán tay
      ls_item_log-invoicefiscalyear = ls_item-invoicereffiscalyear.

      MODIFY zfi_tb_upload_i FROM @ls_item_log.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


