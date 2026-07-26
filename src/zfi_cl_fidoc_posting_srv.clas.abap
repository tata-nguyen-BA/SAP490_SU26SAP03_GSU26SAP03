"! <p class="shorttext synchronized" lang="vn">FI Document Posting – Dịch vụ hạch toán RAP (Orchestrator)</p>
CLASS zfi_cl_fidoc_posting_srv DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_eml_post_input TYPE TABLE FOR ACTION IMPORT i_journalentrytp~post.

    METHODS constructor
      IMPORTING io_log_srv TYPE REF TO zfi_cl_fidoc_log_srv.

    METHODS post
      IMPORTING it_eml_input TYPE ty_eml_post_input
                it_data      TYPE zfi_if_fidoc_types=>tt_data
                iv_is_update TYPE abap_bool
      EXPORTING et_results   TYPE zfi_if_fidoc_types=>tt_results
                ev_has_error TYPE abap_bool.

    METHODS simulate
      IMPORTING it_eml_input TYPE ty_eml_post_input
      EXPORTING et_results   TYPE zfi_if_fidoc_types=>tt_results.

    "! Hạch toán hoặc mô phỏng qua SOAP API cho các chứng từ Negative Posting.
    "! Khi iv_testmode = abap_true, SOAP XML sẽ chứa TestDataIndicator = true → SAP chỉ validate, không tạo chứng từ.
    METHODS post_soap
      IMPORTING it_data      TYPE zfi_if_fidoc_types=>tt_data
                iv_is_update TYPE abap_bool
                iv_testmode  TYPE abap_bool DEFAULT abap_false
      EXPORTING et_results   TYPE zfi_if_fidoc_types=>tt_results.

  PRIVATE SECTION.
    DATA mo_log_srv TYPE REF TO zfi_cl_fidoc_log_srv.

    METHODS update_invoice_reference
      IMPORTING is_header         TYPE zfi_if_fidoc_types=>ts_data
                is_accounting_doc TYPE zfi_if_fidoc_types=>ts_accounting_document
      CHANGING  ct_results        TYPE zfi_if_fidoc_types=>tt_results.

    "! Xây dựng SOAP XML payload cho JournalEntryBulkCreateRequest.
    "! Khi iv_testmode = abap_true → thêm thẻ TestDataIndicator vào JournalEntry header.
    METHODS build_soap_xml
      IMPORTING is_header     TYPE zfi_if_fidoc_types=>ts_data
                iv_testmode   TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rv_xml) TYPE string.

    METHODS parse_soap_response
      IMPORTING iv_xml_response    TYPE string
                is_header          TYPE zfi_if_fidoc_types=>ts_data
                iv_testmode        TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rs_response) TYPE zfi_if_fidoc_types=>ts_soap_response.

    METHODS get_tag_value
      IMPORTING iv_xml          TYPE string
                iv_tag          TYPE string
      RETURNING VALUE(rv_value) TYPE string.

ENDCLASS.



CLASS zfi_cl_fidoc_posting_srv IMPLEMENTATION.


  METHOD constructor.
    mo_log_srv = io_log_srv.
  ENDMETHOD.


  METHOD post.
    ev_has_error = abap_false.

    MODIFY ENTITIES OF i_journalentrytp ENTITY journalentry
           EXECUTE post FROM it_eml_input
           FAILED   DATA(ls_failed)
           REPORTED DATA(ls_reported)
           MAPPED   DATA(ls_mapped).

    LOOP AT ls_reported-JournalEntry INTO DATA(ls_rep).
      APPEND INITIAL LINE TO et_results ASSIGNING FIELD-SYMBOL(<ls_res>).
      SPLIT ls_rep-%cid AT '#' INTO <ls_res>-filename <ls_res>-id_doc DATA(lv_dummy_uuid).

      <ls_res>-type = COND #(
          WHEN ls_rep-%msg->if_t100_dyn_msg~msgty = 'E' THEN 'Error'
          WHEN ls_rep-%msg->if_t100_dyn_msg~msgty = 'W' THEN 'Warning'
          ELSE 'Success' ).
      <ls_res>-message = ls_rep-%msg->if_message~get_text( ).
    ENDLOOP.

    IF ls_failed IS NOT INITIAL.
      ev_has_error = abap_true.
      RETURN.
    ENDIF.

    COMMIT ENTITIES BEGIN RESPONSE OF i_journalentrytp
           FAILED   DATA(lt_c_fail)
           REPORTED DATA(lt_c_rep).
    COMMIT ENTITIES END.

    LOOP AT ls_mapped-JournalEntry INTO DATA(ls_map).
      READ TABLE lt_c_rep-JournalEntry INTO DATA(ls_c_rep) WITH KEY %pid = ls_map-%pid.
      DATA(ls_ac_doc) = VALUE zfi_if_fidoc_types=>ts_accounting_document(
          accountingdocument = ls_c_rep-%msg->if_t100_dyn_msg~msgv2(10)
          companycode        = ls_c_rep-%msg->if_t100_dyn_msg~msgv2+10(4)
          fiscalyear         = ls_c_rep-%msg->if_t100_dyn_msg~msgv2+14(4) ).

      SPLIT ls_map-%cid AT '#' INTO DATA(lv_fname) DATA(lv_did) DATA(lv_uuid).
      READ TABLE it_data INTO DATA(ls_header) WITH KEY filename = lv_fname id_doc = lv_did.
      IF sy-subrc <> 0. CONTINUE. ENDIF.

      update_invoice_reference( EXPORTING is_header = ls_header is_accounting_doc = ls_ac_doc CHANGING ct_results = et_results ).
      mo_log_srv->save( is_header = ls_header is_accounting_doc = ls_ac_doc iv_is_update = iv_is_update ).

      APPEND VALUE #(
          filename           = lv_fname
          id_doc             = lv_did
          accountingdocument = ls_ac_doc-accountingdocument
          type               = 'Success'
          message            = |Chứng từ { ls_ac_doc-accountingdocument } đã được tạo.| ) TO et_results.
    ENDLOOP.
  ENDMETHOD.


  METHOD simulate.
    DATA lt_check_data TYPE TABLE FOR FUNCTION IMPORT i_journalentrytp~validate.
    lt_check_data = CORRESPONDING #( it_eml_input ).

    READ ENTITIES OF i_journalentrytp ENTITY journalentry
         EXECUTE validate FROM lt_check_data
         RESULT   DATA(lt_check_result)
         FAILED   DATA(ls_failed_c)
         REPORTED DATA(ls_reported_c).

    LOOP AT ls_reported_c-JournalEntry INTO DATA(ls_rep_c).
      APPEND INITIAL LINE TO et_results ASSIGNING FIELD-SYMBOL(<ls_res>).
      SPLIT ls_rep_c-%cid AT '#' INTO <ls_res>-filename <ls_res>-id_doc DATA(lv_dummy).

      <ls_res>-message = ls_rep_c-%msg->if_message~get_text( ).
      <ls_res>-type    = COND #(
          WHEN ls_rep_c-%msg->if_t100_dyn_msg~msgty = 'E' THEN 'Error'
          WHEN ls_rep_c-%msg->if_t100_dyn_msg~msgty = 'S' THEN 'Success'
          WHEN ls_rep_c-%msg->if_t100_dyn_msg~msgty = 'W' THEN 'Warning'
          WHEN ls_rep_c-%msg->if_t100_dyn_msg~msgty = 'I' THEN 'Information'
          ELSE ls_rep_c-%msg->if_t100_dyn_msg~msgty ).
    ENDLOOP.
  ENDMETHOD.


  METHOD post_soap.
    LOOP AT it_data INTO DATA(ls_header).

      DATA(lv_xml_request) = build_soap_xml( is_header   = ls_header
                                             iv_testmode = iv_testmode ).

      IF lv_xml_request IS INITIAL.
        APPEND VALUE #( filename = ls_header-filename
                        id_doc   = ls_header-id_doc
                        type     = 'Error'
                        message  = |Không có dòng hạch toán hợp lệ để tạo SOAP XML.| ) TO et_results.
        CONTINUE.
      ENDIF.

      DATA lv_xml_response TYPE string.
      DATA lv_guid         TYPE string.

      TRY.
          lv_guid = cl_uuid_factory=>create_system_uuid( )->create_uuid_x16( ).
        CATCH cx_uuid_error.
          lv_guid = |{ sy-datum }{ sy-uzeit }|.
      ENDTRY.

*      TRY.
*          DATA(lo_destination) =
*            cl_http_destination_provider=>create_by_comm_arrangement( comm_scenario = 'ZCORE_CS_SAP'
*                                                                      service_id    = 'ZCORE_OS_SAP_REST' ).
*
*          DATA(lo_http_client) =
*            cl_web_http_client_manager=>create_by_http_destination( i_destination = lo_destination ).
*
*          DATA(lo_request) = lo_http_client->get_http_request( ).
*          lo_request->set_header_field( i_name  = 'Content-Type'
*                                        i_value = 'text/xml; charset=UTF-8' ).
*          lo_request->set_uri_path( |/sap/bc/srt/scs_ext/sap/journalentrycreaterequestconfi?MessageId={ lv_guid }| ).
*          lo_request->set_text( lv_xml_request ).
*
*          DATA(lo_response) = lo_http_client->execute( i_method = if_web_http_client=>post ).
*          lv_xml_response = lo_response->get_text( ).
*
*        CATCH cx_http_dest_provider_error INTO DATA(lx_dest).
*          APPEND VALUE #( filename = ls_header-filename
*                          id_doc   = ls_header-id_doc
*                          type     = 'Error'
*                          message  = lx_dest->get_text( ) ) TO et_results.
*          CONTINUE.
*
*        CATCH cx_web_http_client_error INTO DATA(lx_http).
*          APPEND VALUE #( filename = ls_header-filename
*                          id_doc   = ls_header-id_doc
*                          type     = 'Error'
*                          message  = lx_http->get_text( ) ) TO et_results.
*          CONTINUE.
*      ENDTRY.

      TRY.
          DATA(lo_http_wrap) = NEW zfi_cl_fidoc_http_wrap( ).
          lv_xml_response = lo_http_wrap->send_soap(
              iv_destination = CONV rfcdest( 'ZSAP_LOOPBACK' )
              iv_uri_path    = |/sap/bc/srt/xip/sap/journalentrycreaterequestconfi/324/zbnd_je_create/zbinding_je_create?sap-client=324|
              iv_payload     = lv_xml_request ).

        CATCH cx_web_http_client_error INTO DATA(lx_http).
          APPEND VALUE #( filename = ls_header-filename
                          id_doc   = ls_header-id_doc
                          type     = 'Error'
                          message  = lx_http->get_text( ) ) TO et_results.
          CONTINUE.
      ENDTRY.

      DATA(ls_soap_result) = parse_soap_response( iv_xml_response = lv_xml_response
                                                  is_header       = ls_header
                                                  iv_testmode     = iv_testmode ).

      IF ls_soap_result-has_error = abap_true.
        APPEND LINES OF ls_soap_result-messages TO et_results.
        CONTINUE.
      ENDIF.

      " Chế độ mô phỏng: không ghi log, không ghi chứng từ — chỉ trả kết quả validate
      IF iv_testmode = abap_true.
        APPEND LINES OF ls_soap_result-messages TO et_results.
        CONTINUE.
      ENDIF.

      " Hạch toán thật thành công → ghi log
      DATA(ls_ac_doc) = VALUE zfi_if_fidoc_types=>ts_accounting_document(
                                  AccountingDocument = ls_soap_result-accountingdocument
                                  CompanyCode        = ls_soap_result-companycode
                                  FiscalYear         = ls_soap_result-fiscalyear ).

      mo_log_srv->save( is_header         = ls_header
                        is_accounting_doc = ls_ac_doc
                        iv_is_update      = iv_is_update ).
      " start modify
*      APPEND VALUE #(
*          filename           = ls_header-filename
*          id_doc             = ls_header-id_doc
*          accountingdocument = ls_soap_result-accountingdocument
*          type               = 'Success'
*          message            = |Chứng từ { ls_soap_result-accountingdocument } đã được tạo (Negative Posting).| ) TO et_results.
      " Nhận diện chứng từ có dòng negative posting không -> label message
      DATA(lv_is_negative) = abap_false.
      LOOP AT ls_header-to_item TRANSPORTING NO FIELDS WHERE negativeposting IS NOT INITIAL.
        lv_is_negative = abap_true.
        EXIT.
      ENDLOOP.

      APPEND VALUE #(
          filename           = ls_header-filename
          id_doc             = ls_header-id_doc
          accountingdocument = ls_soap_result-accountingdocument
          type               = 'Success'
          message            = COND #(
              WHEN lv_is_negative = abap_true
              THEN |Chứng từ { ls_soap_result-accountingdocument } đã được tạo (Negative Posting).|
              ELSE |Chứng từ { ls_soap_result-accountingdocument } đã được tạo.| ) ) TO et_results.
      " end modify

    ENDLOOP.
  ENDMETHOD.


  METHOD build_soap_xml.
    SELECT DISTINCT i_postingkey~PostingKey,
                    i_postingkey~FinancialAccountType,
                    i_postingkey~DebitCreditCode
      FROM I_PostingKey
             INNER JOIN
               @is_header-to_item AS item ON item~postingkey = i_postingkey~PostingKey
      INTO TABLE @DATA(lt_postingkey).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    SORT lt_postingkey BY postingkey.

    DATA lv_msgid TYPE string.
    TRY.
        lv_msgid = cl_uuid_factory=>create_system_uuid( )->create_uuid_x16( ).
      CATCH cx_uuid_error.
        lv_msgid = |MSG_{ sy-datum }{ sy-uzeit }|.
    ENDTRY.
    DATA(lv_now) = |{ sy-datum DATE = ISO }T{ sy-uzeit TIME = ISO }Z|.

    rv_xml = '<?xml version="1.0" encoding="UTF-8"?>'.
    rv_xml &&= '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"'.
    rv_xml &&= ' xmlns:sfin="http://sap.com/xi/SAPSCORE/SFIN">'.
    rv_xml &&= '<soapenv:Header/>'.
    rv_xml &&= '<soapenv:Body>'.
    rv_xml &&= '<sfin:JournalEntryBulkCreateRequest>'.

    rv_xml &&= '<MessageHeader>'.
    rv_xml &&= |<ID>{ lv_msgid }</ID>|.
    rv_xml &&= |<CreationDateTime>{ lv_now }</CreationDateTime>|.

    IF iv_testmode = abap_true.
      rv_xml &&= '<TestDataIndicator>true</TestDataIndicator>'.
    ENDIF.

    rv_xml &&= '</MessageHeader>'.

    rv_xml &&= '<JournalEntryCreateRequest>'.
    rv_xml &&= '<MessageHeader>'.
    rv_xml &&= |<ID>SM_{ lv_msgid }</ID>|.
    rv_xml &&= |<CreationDateTime>{ lv_now }</CreationDateTime>|.
    rv_xml &&= '</MessageHeader>'.

    rv_xml &&= '<JournalEntry>'.
    rv_xml &&= |<OriginalReferenceDocumentType>BKPFF</OriginalReferenceDocumentType>|.
    rv_xml &&= '<BusinessTransactionType>RFBU</BusinessTransactionType>'.
    rv_xml &&= |<AccountingDocumentType>{ is_header-documenttype }</AccountingDocumentType>|.
    rv_xml &&= |<DocumentHeaderText>{ is_header-headertext }</DocumentHeaderText>|.
    rv_xml &&= |<CreatedByUser>{ sy-uname }</CreatedByUser>|.
    rv_xml &&= |<CompanyCode>{ is_header-companycode }</CompanyCode>|.
    rv_xml &&= |<DocumentDate>{ is_header-documentdate DATE = ISO }</DocumentDate>|.
    rv_xml &&= |<PostingDate>{ is_header-postingdate DATE = ISO }</PostingDate>|.

    DATA lv_itemno TYPE i.
    lv_itemno = 0.

    LOOP AT is_header-to_item INTO DATA(ls_item).
      READ TABLE lt_postingkey INTO DATA(ls_pk)
           WITH KEY postingkey = ls_item-postingkey BINARY SEARCH.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      lv_itemno += 1.

      DATA(lv_amount)  = ls_item-amountindoumentcurrency * 100.
      DATA(lv_dc_code) = ls_pk-DebitCreditCode.

      " Quy tắc dấu thống nhất (verify từ 0090001687 thường + 0090001685 negative):
      " - Dòng thường:   S -> dương, H -> âm
      " - Dòng negative: GIỮ NGUYÊN DC theo posting key, ĐẢO dấu so với dòng thường
      "   (S+negp -> âm, H+negp -> dương) kèm cờ IsNegativePosting
      "   -> Mỗi dòng ghi GIẢM đúng bên của nó, chứng từ luôn tự cân bằng
      IF ls_item-negativeposting IS NOT INITIAL.
        IF lv_dc_code = 'H'.
          lv_amount = abs( lv_amount ).
        ELSE.
          lv_amount = abs( lv_amount ) * -1.
        ENDIF.
      ELSE.
        IF lv_dc_code = 'H'.
          lv_amount = abs( lv_amount ) * -1.
        ELSE.
          lv_amount = abs( lv_amount ).
        ENDIF.
      ENDIF.

      DATA(lv_currency) = COND waers( WHEN ls_item-transactioncurrency IS NOT INITIAL
                                      THEN ls_item-transactioncurrency
                                      ELSE is_header-currency ).

      rv_xml &&= '<Item>'.
      rv_xml &&= |<ReferenceDocumentItem>{ lv_itemno }</ReferenceDocumentItem>|.
      rv_xml &&= |<GLAccount>{ ls_item-account }</GLAccount>|.

      rv_xml &&=
        |<AmountInTransactionCurrency currencyCode="{ lv_currency }">|
        && |{ lv_amount }</AmountInTransactionCurrency>|.

      rv_xml &&= |<DebitCreditCode>{ lv_dc_code }</DebitCreditCode>|.
      IF ls_item-negativeposting IS NOT INITIAL.
        rv_xml &&= '<IsNegativePosting>true</IsNegativePosting>'.
      ENDIF.

      IF    ls_item-wbselement    IS NOT INITIAL
         OR ls_item-costcenter    IS NOT INITIAL
         OR ls_item-internalorder IS NOT INITIAL.
        rv_xml &&= '<AccountAssignment>'.

        IF ls_item-wbselement IS NOT INITIAL.
          rv_xml &&= |<AccountAssignmentType>PR</AccountAssignmentType>|.
          rv_xml &&= |<WBSElement>{ ls_item-wbselement }</WBSElement>|.
        ENDIF.
        IF ls_item-costcenter IS NOT INITIAL.
          IF ls_item-wbselement IS INITIAL.
            rv_xml &&= |<AccountAssignmentType>KS</AccountAssignmentType>|.
          ENDIF.
          rv_xml &&= |<CostCenter>{ ls_item-costcenter }</CostCenter>|.
        ENDIF.
        IF ls_item-internalorder IS NOT INITIAL.
          IF ls_item-wbselement IS INITIAL AND ls_item-costcenter IS INITIAL.
            rv_xml &&= |<AccountAssignmentType>OR</AccountAssignmentType>|.
          ENDIF.
          rv_xml &&= |<OrderID>{ ls_item-internalorder }</OrderID>|.
        ENDIF.

        rv_xml &&= '</AccountAssignment>'.
      ENDIF.

      IF ls_item-profitcenter IS NOT INITIAL.
        rv_xml &&= |<ProfitCenter>{ ls_item-profitcenter }</ProfitCenter>|.
      ENDIF.

      IF ls_item-itemtext IS NOT INITIAL.
        rv_xml &&= |<DocumentItemText>{ ls_item-itemtext }</DocumentItemText>|.
      ENDIF.

      rv_xml &&= '</Item>'.
    ENDLOOP.

    IF lv_itemno = 0.
      CLEAR rv_xml.
      RETURN.
    ENDIF.

    rv_xml &&= '</JournalEntry>'.
    rv_xml &&= '</JournalEntryCreateRequest>'.
    rv_xml &&= '</sfin:JournalEntryBulkCreateRequest>'.
    rv_xml &&= '</soapenv:Body>'.
    rv_xml &&= '</soapenv:Envelope>'.
  ENDMETHOD.


  METHOD parse_soap_response.
    rs_response-has_error = abap_false.

    DATA(lv_doc)   = get_tag_value( iv_xml = iv_xml_response
                                    iv_tag = 'AccountingDocument' ).
    DATA(lv_bukrs) = get_tag_value( iv_xml = iv_xml_response
                                    iv_tag = 'CompanyCode' ).
    DATA(lv_gjahr) = get_tag_value( iv_xml = iv_xml_response
                                    iv_tag = 'FiscalYear' ).

    " Chế độ mô phỏng: SAP trả AccountingDocument = '0000000000' khi thành công
    " Cần kiểm tra MaximumLogItemSeverityCode để xác định có lỗi hay không
    IF iv_testmode = abap_true.
      DATA(lv_max_sev_str) = get_tag_value( iv_xml = iv_xml_response
                                            iv_tag = 'MaximumLogItemSeverityCode' ).
      DATA lv_max_sev TYPE i VALUE 0.
      IF lv_max_sev_str IS NOT INITIAL.
        TRY.
            lv_max_sev = lv_max_sev_str.
          CATCH cx_sy_conversion_no_number.
            lv_max_sev = 0.
        ENDTRY.
      ENDIF.

      " SeverityCode < 3 và không có lỗi nghiêm trọng → simulation thành công
      IF lv_max_sev < 3.
        rs_response-has_error = abap_false.

        " Thu thập tất cả thông báo (kể cả warning/info) để trả về Client
        DATA lv_sim_pos TYPE i VALUE 0.
        DATA(lv_sim_total) = strlen( iv_xml_response ).
        DATA lv_has_any_message TYPE abap_bool VALUE abap_false.

        WHILE lv_sim_pos < lv_sim_total.
          DATA(lv_sim_rem) = lv_sim_total - lv_sim_pos.
          IF lv_sim_rem <= 0.
            EXIT.
          ENDIF.
          DATA(lv_sim_tail) = iv_xml_response+lv_sim_pos(lv_sim_rem).

          DATA lv_sim_off_open TYPE i.
          FIND FIRST OCCURRENCE OF '<Item>' IN lv_sim_tail MATCH OFFSET lv_sim_off_open.
          IF sy-subrc <> 0.
            EXIT.
          ENDIF.

          DATA(lv_sim_item_start) = lv_sim_pos + lv_sim_off_open.
          IF lv_sim_item_start >= lv_sim_total.
            EXIT.
          ENDIF.

          DATA(lv_sim_tail2_len) = lv_sim_total - lv_sim_item_start.
          DATA(lv_sim_tail2)     = iv_xml_response+lv_sim_item_start(lv_sim_tail2_len).

          DATA lv_sim_off_close TYPE i.
          FIND FIRST OCCURRENCE OF '</Item>' IN lv_sim_tail2 MATCH OFFSET lv_sim_off_close.
          IF sy-subrc <> 0.
            EXIT.
          ENDIF.

          DATA(lv_sim_item_end) = lv_sim_item_start + lv_sim_off_close + strlen( '</Item>' ).
          IF lv_sim_item_end > lv_sim_total.
            lv_sim_item_end = lv_sim_total.
          ENDIF.
          IF lv_sim_item_end <= lv_sim_item_start.
            lv_sim_pos = lv_sim_item_start + 1.
            CONTINUE.
          ENDIF.

          DATA(lv_sim_item_len) = lv_sim_item_end - lv_sim_item_start.
          DATA(lv_sim_item_xml) = iv_xml_response+lv_sim_item_start(lv_sim_item_len).
          lv_sim_pos = lv_sim_item_end.

          DATA(lv_sim_note) = get_tag_value( iv_xml = lv_sim_item_xml
                                             iv_tag = 'Note' ).
          DATA(lv_sim_sev)  = get_tag_value( iv_xml = lv_sim_item_xml
                                             iv_tag = 'SeverityCode' ).

          IF lv_sim_note IS NOT INITIAL.
            REPLACE ALL OCCURRENCES OF '&amp;'  IN lv_sim_note WITH '&'.
            REPLACE ALL OCCURRENCES OF '&lt;'   IN lv_sim_note WITH '<'.
            REPLACE ALL OCCURRENCES OF '&gt;'   IN lv_sim_note WITH '>'.
            REPLACE ALL OCCURRENCES OF '&quot;' IN lv_sim_note WITH '"'.
            REPLACE ALL OCCURRENCES OF '&apos;' IN lv_sim_note WITH ''''.

            DATA lv_sim_sev_i TYPE i VALUE 0.
            IF lv_sim_sev IS NOT INITIAL.
              TRY.
                  lv_sim_sev_i = lv_sim_sev.
                CATCH cx_sy_conversion_no_number.
                  lv_sim_sev_i = 0.
              ENDTRY.
            ENDIF.

            " Phân loại message type dựa trên SeverityCode
            DATA(lv_sim_msg_type) = COND string(
                WHEN lv_sim_sev_i >= 3 THEN 'Error'
                WHEN lv_sim_sev_i = 2  THEN 'Warning'
                ELSE                        'Information' ).

            APPEND VALUE #( filename = is_header-filename
                            id_doc   = is_header-id_doc
                            type     = lv_sim_msg_type
                            message  = lv_sim_note ) TO rs_response-messages.
            lv_has_any_message = abap_true.
          ENDIF.
        ENDWHILE.

        IF lv_has_any_message = abap_false.
          APPEND VALUE #( filename = is_header-filename
                          id_doc   = is_header-id_doc
                          type     = 'Success'
                          message  = |Simulation thành công (Negative Posting via SOAP). Dữ liệu hợp lệ.| ) TO rs_response-messages.
        ENDIF.
        RETURN.
      ENDIF.

      " MaximumLogItemSeverityCode >= 3 → simulation thất bại, tiếp tục xuống luồng xử lý lỗi bên dưới
      rs_response-has_error = abap_true.
    ELSE.
      " Chế độ hạch toán thật: chứng từ hợp lệ → thành công
      IF lv_doc IS NOT INITIAL AND lv_doc <> '0000000000'.
        rs_response-accountingdocument = lv_doc.
        rs_response-companycode        = lv_bukrs.
        rs_response-fiscalyear         = lv_gjahr.
        RETURN.
      ENDIF.

      rs_response-has_error = abap_true.
    ENDIF.

    " === Luồng xử lý lỗi chung cho cả simulate và post thật ===
    DATA lv_pos TYPE i VALUE 0.
    DATA(lv_total) = strlen( iv_xml_response ).

    WHILE lv_pos < lv_total.
      DATA(lv_remaining) = lv_total - lv_pos.
      IF lv_remaining <= 0.
        EXIT.
      ENDIF.
      DATA(lv_tail) = iv_xml_response+lv_pos(lv_remaining).

      DATA lv_off_open TYPE i.
      FIND FIRST OCCURRENCE OF '<Item>' IN lv_tail MATCH OFFSET lv_off_open.
      IF sy-subrc <> 0.
        EXIT.
      ENDIF.

      DATA(lv_item_start) = lv_pos + lv_off_open.
      IF lv_item_start >= lv_total.
        EXIT.
      ENDIF.

      DATA(lv_tail2_len) = lv_total - lv_item_start.
      DATA(lv_tail2)     = iv_xml_response+lv_item_start(lv_tail2_len).

      DATA lv_off_close TYPE i.
      FIND FIRST OCCURRENCE OF '</Item>' IN lv_tail2 MATCH OFFSET lv_off_close.
      IF sy-subrc <> 0.
        EXIT.
      ENDIF.

      DATA(lv_item_end) = lv_item_start + lv_off_close + strlen( '</Item>' ).
      IF lv_item_end > lv_total.
        lv_item_end = lv_total.
      ENDIF.
      IF lv_item_end <= lv_item_start.
        lv_pos = lv_item_start + 1.
        CONTINUE.
      ENDIF.

      DATA(lv_item_len) = lv_item_end - lv_item_start.
      DATA(lv_item_xml) = iv_xml_response+lv_item_start(lv_item_len).
      lv_pos = lv_item_end.

      DATA(lv_sev_str) = get_tag_value( iv_xml = lv_item_xml
                                        iv_tag = 'SeverityCode' ).
      DATA(lv_note)    = get_tag_value( iv_xml = lv_item_xml
                                        iv_tag = 'Note' ).

      DATA lv_sev TYPE i VALUE 0.
      IF lv_sev_str IS NOT INITIAL.
        TRY.
            lv_sev = lv_sev_str.
          CATCH cx_sy_conversion_no_number.
            lv_sev = 0.
        ENDTRY.
      ENDIF.

      IF lv_sev >= 3 AND lv_note IS NOT INITIAL.
        REPLACE ALL OCCURRENCES OF '&amp;'  IN lv_note WITH '&'.
        REPLACE ALL OCCURRENCES OF '&lt;'   IN lv_note WITH '<'.
        REPLACE ALL OCCURRENCES OF '&gt;'   IN lv_note WITH '>'.
        REPLACE ALL OCCURRENCES OF '&quot;' IN lv_note WITH '"'.
        REPLACE ALL OCCURRENCES OF '&apos;' IN lv_note WITH ''''.

        APPEND VALUE #( filename = is_header-filename
                        id_doc   = is_header-id_doc
                        type     = 'Error'
                        message  = lv_note ) TO rs_response-messages.
      ENDIF.
    ENDWHILE.

    " Fallback: không bắt được lỗi cụ thể → dump XML response để debug
    IF rs_response-messages IS INITIAL.
      DATA lv_debug_off TYPE i VALUE 0.
      DATA(lv_xml_len) = strlen( iv_xml_response ).
      WHILE lv_debug_off < lv_xml_len.
        DATA(lv_chunk_len) = 200.
        IF lv_debug_off + lv_chunk_len > lv_xml_len.
          lv_chunk_len = lv_xml_len - lv_debug_off.
        ENDIF.
        IF lv_chunk_len <= 0.
          EXIT.
        ENDIF.

        APPEND VALUE #( filename = is_header-filename
                        id_doc   = is_header-id_doc
                        type     = 'Error'
                        message  = iv_xml_response+lv_debug_off(lv_chunk_len) ) TO rs_response-messages.
        lv_debug_off += lv_chunk_len.
      ENDWHILE.
    ENDIF.
  ENDMETHOD.


  METHOD get_tag_value.
    DATA(lv_open)  = |<{ iv_tag }>|.
    DATA(lv_close) = |</{ iv_tag }>|.

    DATA lv_s TYPE i.
    FIND FIRST OCCURRENCE OF lv_open IN iv_xml MATCH OFFSET lv_s.
    IF sy-subrc <> 0. RETURN. ENDIF.
    lv_s += strlen( lv_open ).

    DATA lv_e TYPE i.
    FIND FIRST OCCURRENCE OF lv_close IN iv_xml MATCH OFFSET lv_e.
    IF sy-subrc <> 0 OR lv_e <= lv_s. RETURN. ENDIF.

    DATA(lv_len) = lv_e - lv_s.
    IF lv_s + lv_len > strlen( iv_xml ). RETURN. ENDIF.

    rv_value = iv_xml+lv_s(lv_len).
  ENDMETHOD.


  METHOD update_invoice_reference.
    SELECT DISTINCT AccountingDocumentItem, FinancialAccountType
      FROM i_journalentryitem
      WHERE Ledger             = '0L'
        AND AccountingDocument = @is_accounting_doc-accountingdocument
        AND FiscalYear         = @is_accounting_doc-fiscalyear
        AND ( FinancialAccountType = 'K' OR FinancialAccountType = 'D' )
      INTO TABLE @DATA(lt_jei).

    IF sy-subrc <> 0. RETURN. ENDIF.

    DATA lt_je_change TYPE TABLE FOR ACTION IMPORT i_journalentrytp~change.
    APPEND INITIAL LINE TO lt_je_change ASSIGNING FIELD-SYMBOL(<je>).
    <je>-AccountingDocument = is_accounting_doc-accountingdocument.
    <je>-FiscalYear         = is_accounting_doc-fiscalyear.
    <je>-CompanyCode        = is_accounting_doc-companycode.

    DATA(lv_update_needed) = abap_false.

    LOOP AT lt_jei INTO DATA(ls_jei).
      READ TABLE is_header-to_item INTO DATA(ls_orig) WITH KEY idline = ls_jei-AccountingDocumentItem.
      IF sy-subrc = 0 AND ls_orig-invoicerefnum IS NOT INITIAL.
        lv_update_needed = abap_true.

        APPEND INITIAL LINE TO <je>-%param-_aparitems REFERENCE INTO DATA(lr_apar).
        lr_apar->glaccountlineitem          = ls_jei-AccountingDocumentItem.
        lr_apar->invoicereference           = ls_orig-invoicerefnum.
        lr_apar->invoiceitemreference       = ls_orig-invoicereflineitem.
        lr_apar->invoicereferencefiscalyear = ls_orig-invoicereffiscalyear.

        lr_apar->%control = VALUE #(
            InvoiceReference           = if_abap_behv=>mk-on
            InvoiceItemReference       = if_abap_behv=>mk-on
            InvoiceReferenceFiscalYear = if_abap_behv=>mk-on ).
      ENDIF.
    ENDLOOP.

    IF lv_update_needed = abap_false.
      APPEND VALUE #( accountingdocument = is_accounting_doc-accountingdocument type = 'Success' message = 'Posted' ) TO ct_results.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF i_journalentrytp ENTITY journalentry
           EXECUTE change FROM lt_je_change
           FAILED   DATA(ls_fail)
           REPORTED DATA(ls_rep).

    IF ls_fail IS NOT INITIAL.
      LOOP AT ls_rep-JournalEntry INTO DATA(ls_log).
        APPEND VALUE #( type = 'Error' message = ls_log-%msg->if_message~get_text( ) ) TO ct_results.
      ENDLOOP.
    ELSE.
      COMMIT ENTITIES BEGIN RESPONSE OF i_journalentrytp FAILED DATA(cf) REPORTED DATA(cr).
      COMMIT ENTITIES END.
      APPEND VALUE #( accountingdocument = is_accounting_doc-accountingdocument type = 'Success' message = 'Posted & Updated' ) TO ct_results.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
