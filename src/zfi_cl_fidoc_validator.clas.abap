CLASS zfi_cl_fidoc_validator DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING is_request TYPE zfi_if_fidoc_types=>ts_post_request.

    METHODS validate
      EXPORTING et_data             TYPE zfi_if_fidoc_types=>tt_data
                et_errors           TYPE zfi_if_fidoc_types=>tt_results
      RETURNING VALUE(rv_has_error) TYPE abap_bool.

  PRIVATE SECTION.
    DATA ms_request TYPE zfi_if_fidoc_types=>ts_post_request.

    METHODS convert_and_validate_item
      IMPORTING is_raw               TYPE zfi_if_fidoc_types=>ts_doc_item_request
                iv_doc_id            TYPE string
      EXPORTING es_item              TYPE zfi_if_fidoc_types=>ts_item
                et_item_errors       TYPE zfi_if_fidoc_types=>tt_results
      RETURNING VALUE(rv_item_valid) TYPE abap_bool.

    "! Đổi chuỗi số tiền từ Excel sang số, KHÔNG phụ thuộc Decimal Notation
    "! của user trong SU3. Nhận cả 1.000,50 (VN/DE) lẫn 1,000.50 (US).
    "! Cùng quy tắc với UploadValidator.parseNumber ở frontend để client và
    "! backend không hiểu khác nhau trên cùng một chuỗi.
    CLASS-METHODS conv_amount
      IMPORTING iv_value         TYPE string
      RETURNING VALUE(rv_amount) TYPE fins_vwcur12.

ENDCLASS.



CLASS zfi_cl_fidoc_validator IMPLEMENTATION.


  METHOD constructor.
    ms_request = is_request.
  ENDMETHOD.


  METHOD validate.
    rv_has_error = abap_false.

    LOOP AT ms_request-doc INTO DATA(ls_doc).
      DATA(ls_data) = VALUE zfi_if_fidoc_types=>ts_data( filename        = ms_request-filename
                                                         id_doc          = ls_doc-id_doc
                                                         companycode     = ls_doc-companycode
                                                         documentdate    = ls_doc-documentdate
                                                         postingdate     = ls_doc-postingdate
                                                         documenttype    = ls_doc-documenttype
                                                         currency        = ls_doc-currency
                                                         headertext      = ls_doc-headertext
                                                         referencedoc    = ls_doc-referencedoc
                                                         headerref1      = ls_doc-headerref_1 ).

      LOOP AT ls_doc-to_item INTO DATA(ls_raw_item).
        ls_raw_item-AccountingDocumentItem = sy-tabix.

        DATA(ls_converted_item) = VALUE zfi_if_fidoc_types=>ts_item( ).
        DATA(lt_item_errors)    = VALUE zfi_if_fidoc_types=>tt_results( ).

        DATA(lv_item_valid) = convert_and_validate_item( EXPORTING is_raw         = ls_raw_item
                                                                   iv_doc_id      = ls_doc-id_doc
                                                         IMPORTING es_item        = ls_converted_item
                                                                   et_item_errors = lt_item_errors ).

        APPEND LINES OF lt_item_errors TO et_errors.
        IF lt_item_errors IS NOT INITIAL.
          rv_has_error = abap_true.
        ENDIF.

        IF lv_item_valid = abap_true.
          APPEND ls_converted_item TO ls_data-to_item.
        ENDIF.
      ENDLOOP.

      APPEND ls_data TO et_data.
    ENDLOOP.
  ENDMETHOD.


  METHOD convert_and_validate_item.
    rv_item_valid     = abap_true.
    DATA(lv_filename) = CONV zfi_de_filename( ms_request-filename ).

    IF is_raw-amountindoumentcurrency IS INITIAL OR is_raw-amountindoumentcurrency = '0'.
      APPEND VALUE #(
          filename = lv_filename
          id_doc   = iv_doc_id
          type     = 'Error'
          message  = |ID Doc { iv_doc_id } - Dòng { is_raw-idline }: Thiếu field "Amount in Document Currency". Vui lòng điền giá trị.| )
             TO et_item_errors.
      rv_item_valid = abap_false.
      RETURN.
    ENDIF.

    IF     is_raw-localtaxbaseamount IS NOT INITIAL AND is_raw-localtaxbaseamount <> '0'
       AND ( is_raw-taxbaseamount IS INITIAL OR is_raw-taxbaseamount = '0' ).
      APPEND VALUE #(
          filename = lv_filename
          id_doc   = iv_doc_id
          type     = 'Error'
          message  = |ID Doc { iv_doc_id } - Dòng { is_raw-idline }: Đã điền "Tax Base Amount in Local Currency" nhưng thiếu "Tax Base Amount in Document Currency".| )
             TO et_item_errors.
      rv_item_valid = abap_false.
      RETURN.
    ENDIF.

    "═══════════════════════════════════════════════════════════════════════
    " ĐỔI SỐ TIỀN (sửa 28/07/2026)
    "
    " Code cũ:
    "     DATA lv_doc_cur   TYPE i VALUE 1.
    "     DATA lv_local_cur TYPE i VALUE 100.
    "     IF is_raw-transactioncurrency = 'VND'. lv_doc_cur = 100. ENDIF.
    "     ... CONV fins_vwcur12( is_raw-amountindoumentcurrency / lv_doc_cur )
    "
    " is_raw-* là STRING. ABAP đổi string sang số theo Decimal Notation của
    " user trong SU3. DEV-CLH đang để 1.234.567,89 nên dấu chấm bị hiểu là
    " phân cách hàng nghìn: "1000.00" thành 100000.
    "
    " Hai hằng số chia kia là workaround cho đúng hiện tượng đó, nhưng chỉ
    " phủ 3/4 trường hợp: doc amount của currency KHÁC VND chia cho 1 nên
    " không được bù -> mọi chứng từ USD/EUR đã post đều gấp 100 lần.
    " Bằng chứng: FB03 chứng từ 100000036, file ghi 1000.00, SAP hiện
    " 100.000,00 EUR.
    "
    " Cách sửa: chuẩn hóa chuỗi tường minh bằng conv_amount, không phụ thuộc
    " SU3 nữa -> BỎ luôn cả hai divisor.
    "═══════════════════════════════════════════════════════════════════════
    DATA(lv_amount_local)   = conv_amount( CONV string( is_raw-amountinlocalcurrency ) ).
    DATA(lv_local_tax_base) = conv_amount( CONV string( is_raw-localtaxbaseamount ) ).
    DATA(lv_amount_doc_cur) = conv_amount( CONV string( is_raw-amountindoumentcurrency ) ).
    DATA(lv_tax_base_doc)   = conv_amount( CONV string( is_raw-taxbaseamount ) ).

    TRY.
        es_item = VALUE #( idline                  = is_raw-idline
                           accountingdocumentitem  = |{ is_raw-accountingdocumentitem ALPHA = IN }|
                           postingkey              = is_raw-postingkey
                           account                 = |{ is_raw-account                ALPHA = IN }|
                           mainassetnumber         = |{ is_raw-mainassetnumber         ALPHA = IN }|
                           subassetnumber          = |{ is_raw-subassetnumber          ALPHA = IN }|
                           profitcenter            = |{ is_raw-profitcenter            ALPHA = IN }|
                           invoicerefnum           = |{ is_raw-invoicerefnum           ALPHA = IN }|
                           invoicereflineitem      = |{ is_raw-invoicereflineitem      ALPHA = IN }|
                           purchasingno            = |{ is_raw-purchasingno            ALPHA = IN }|
                           purchasingitem          = |{ is_raw-purchasingitem          ALPHA = IN }|
                           saleorder               = |{ is_raw-saleorder               ALPHA = IN }|
                           saleorderitem           = |{ is_raw-saleorderitem           ALPHA = IN }|
                           customer                = |{ is_raw-customer                ALPHA = IN }|
                           product                 = |{ is_raw-product                 ALPHA = IN WIDTH = 18 }|

                           amountinlocalcurrency   = lv_amount_local
                           amountindoumentcurrency = lv_amount_doc_cur
                           taxbaseamount           = lv_tax_base_doc
                           localtaxbaseamount      = lv_local_tax_base

                           specialglaccount        = is_raw-specialglaccount
                           assettransactiontype    = is_raw-assettransactiontype
                           companycodecurrency     = is_raw-companycodecurrency
                           transactioncurrency     = is_raw-transactioncurrency

                           " CHƯA SỬA - cùng loại lỗi với số tiền: string sang
                           " DEC(13,5) vẫn theo SU3. Phải quyết chung với dòng
                           " ls_item-exchangerate /= 1000 trong ZFI_CL_FIDOC_MAPPER,
                           " sửa riêng lẻ là lệch nhau. Xem FIX3_amount_conversion.md
                           exchangerate            = is_raw-exchangerate

                           assignment              = is_raw-assignment
                           businessarea            = is_raw-businessarea
                           costcenter              = is_raw-costcenter
                           internalorder           = is_raw-internalorder
                           assetvaluedate          = is_raw-assetvaluedate
                           itemtext                = is_raw-itemtext
                           overrideglaccount       = is_raw-overrideglaccount
                           taxcode                 = is_raw-taxcode
                           segment                 = is_raw-segment
                           paymentterms            = is_raw-paymentterms
                           paymentblockreason      = is_raw-paymentblockreason
                           paymentmethod           = is_raw-paymentmethod
                           contractnumber          = is_raw-contractnumber
                           contracttype            = is_raw-contracttype
                           housebank               = is_raw-housebank
                           bankaccountid           = is_raw-bankaccountid
                           invoicereffiscalyear    = is_raw-invoicereffiscalyear
                           baselinedate            = is_raw-baselinedate
                           valuedate               = is_raw-valuedate

                           ref1                    = is_raw-ref_1
                           ref2                    = is_raw-ref_2
                           ref3                    = is_raw-ref_3
                           longtext                = is_raw-longtext
                           unit                    = is_raw-unit
                           name1                   = is_raw-name_1
                           name2                   = is_raw-name_2
                           name3                   = is_raw-name_3
                           name4                   = is_raw-name_4
                           city                    = is_raw-city
                           country                 = is_raw-country
                           mst                     = is_raw-mst
                           namecus1                = is_raw-namecus_1
                           namecus2                = is_raw-namecus_2
                           namecus3                = is_raw-namecus_3
                           namecus4                = is_raw-namecus_4
                           citycus                 = is_raw-citycus
                           countrycus              = is_raw-countrycus
                           mstcus                  = is_raw-mstcus
                           vatregno                = is_raw-vatregno

                           " CHƯA SỬA - cùng loại lỗi: string sang MENGE_D(3 thập
                           " phân) vẫn theo SU3. Ít dùng nên tách ra sửa sau.
                           quantity                = is_raw-quantity

                           alternativepayee        = is_raw-alternativepayee
                           tennccxuathd            = is_raw-tennccxuathd
                           mstnccxuathd            = is_raw-mstnccxuathd
                           netduedate              = is_raw-netduedate
                           cusgroup                = is_raw-cusgroup
                           division                = is_raw-division
                           distributionchannel     = is_raw-distributionchannel
                           materialgroup           = is_raw-materialgroup
                           wbselement              = is_raw-wbselement
                           plant                   = is_raw-plant
                           salesorganization       = is_raw-salesorganization
                           countrygl               = is_raw-countrygl
                           namemotzeiv             = is_raw-namemotzeiv
                           cityzeiv                = is_raw-cityzeiv
                           baseunit                = is_raw-baseunit
                           orderid                 = is_raw-orderid
                           material                = is_raw-material
                           negativeposting         = is_raw-negativeposting ).

      CATCH cx_sy_conversion_no_number INTO DATA(lx_conv).
        APPEND VALUE #( filename = lv_filename
                        id_doc   = iv_doc_id
                        type     = 'Error'
                        message  = |ID Doc { iv_doc_id } - Dòng { is_raw-idline }: { lx_conv->get_longtext( ) }| )
               TO et_item_errors.
        rv_item_valid = abap_false.
    ENDTRY.
  ENDMETHOD.


  METHOD conv_amount.
    DATA lv_str  TYPE string.
    DATA lv_int  TYPE string.
    DATA lv_frac TYPE string.
    DATA lv_neg  TYPE abap_bool.
    DATA lv_num  TYPE decfloat34.

    rv_amount = 0.

    lv_str = iv_value.
    CONDENSE lv_str NO-GAPS.
    IF lv_str IS INITIAL.
      RETURN.
    ENDIF.

    IF lv_str CS '-'.
      lv_neg = abap_true.
      REPLACE ALL OCCURRENCES OF '-' IN lv_str WITH ``.
    ENDIF.
    REPLACE ALL OCCURRENCES OF '+' IN lv_str WITH ``.

    DATA(lv_dot)   = find( val = lv_str sub = '.' occ = -1 ).
    DATA(lv_comma) = find( val = lv_str sub = ',' occ = -1 ).

    IF lv_dot >= 0 AND lv_comma >= 0.
      IF lv_dot > lv_comma.
        " 1,000.50 -> dấu phẩy là phân cách hàng nghìn
        REPLACE ALL OCCURRENCES OF ',' IN lv_str WITH ``.
      ELSE.
        " 1.000,50 -> dấu chấm là phân cách hàng nghìn
        REPLACE ALL OCCURRENCES OF '.' IN lv_str WITH ``.
        REPLACE ALL OCCURRENCES OF ',' IN lv_str WITH '.'.
      ENDIF.

    ELSEIF lv_comma >= 0.
      IF strlen( lv_str ) - lv_comma - 1 = 3.
        REPLACE ALL OCCURRENCES OF ',' IN lv_str WITH ``.   " 1,234 = một nghìn hai
      ELSE.
        REPLACE ALL OCCURRENCES OF ',' IN lv_str WITH '.'.  " 1,5 = một phẩy năm
      ENDIF.

    ELSEIF lv_dot >= 0.
      IF strlen( lv_str ) - lv_dot - 1 = 3.
        REPLACE ALL OCCURRENCES OF '.' IN lv_str WITH ``.   " 1.234 = một nghìn hai
      ENDIF.
    ENDIF.

    " Tách phần nguyên và phần thập phân rồi cộng lại.
    " Hai chuỗi này chỉ còn chữ số nên CONV không còn phụ thuộc SU3.
    SPLIT lv_str AT '.' INTO lv_int lv_frac.
    IF lv_int IS INITIAL.
      lv_int = '0'.
    ENDIF.

    TRY.
        lv_num = CONV decfloat34( lv_int ).
        IF lv_frac IS NOT INITIAL.
          lv_num = lv_num + CONV decfloat34( lv_frac ) / ipow( base = 10 exp = strlen( lv_frac ) ).
        ENDIF.
      CATCH cx_sy_conversion_no_number.
        RETURN.
    ENDTRY.

    IF lv_neg = abap_true.
      lv_num = lv_num * -1.
    ENDIF.

    rv_amount = lv_num.
  ENDMETHOD.


ENDCLASS.

