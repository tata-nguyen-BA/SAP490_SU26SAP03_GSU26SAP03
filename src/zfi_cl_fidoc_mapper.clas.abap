"! <p class="shorttext synchronized" lang="vn">FI Document Posting – Mapping EML cho Journal Entry TP</p>
"! <strong>Quyết định thiết kế</strong>:
"! <ul>
"!   <li><strong>Stateless:</strong> Các method public đều mang tính tất định, an toàn khi tái sử dụng instance giữa các request.</li>
"!   <li><strong>Lookup Metadata:</strong> Lệnh SELECT từ I_POSTINGKEY được đặt tại đây để xác định FinancialAccountType định hướng item vào đúng EML collection (AP/AR/GL/Tax).</li>
"!   <li><strong>Tỷ giá:</strong> Logic chia 1000 được thực hiện tại đây nhằm chuẩn hóa đầu vào tính toán trước khi ánh xạ.</li>
"! </ul>
CLASS zfi_cl_fidoc_mapper DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Ánh xạ dữ liệu sang cấu trúc EML để sử dụng cho Action POST của I_JournalEntryTP.
    METHODS map_to_eml_post
      IMPORTING it_data             TYPE zfi_if_fidoc_types=>tt_data
      RETURNING VALUE(rt_post_data) TYPE zfi_if_fidoc_types=>tt_post_data.

  PRIVATE SECTION.
    METHODS fill_currency_amount
      IMPORTING is_item           TYPE zfi_if_fidoc_types=>ts_item
                iv_debit_credit   TYPE c
      RETURNING VALUE(rt_amounts) TYPE zfi_if_fidoc_types=>tt_currency_amount_calc.

    METHODS fill_onetime_partner
      IMPORTING is_item           TYPE zfi_if_fidoc_types=>ts_item
                iv_account_type   TYPE c
      RETURNING VALUE(rs_partner) TYPE zfi_if_fidoc_types=>ts_onetime_partner.

ENDCLASS.



CLASS zfi_cl_fidoc_mapper IMPLEMENTATION.


  METHOD map_to_eml_post.
    LOOP AT it_data INTO DATA(ls_header).
      APPEND INITIAL LINE TO rt_post_data ASSIGNING FIELD-SYMBOL(<lfs_entry>).

      " Tạo Correlation ID (CID) để liên kết/truy vết kết quả EML sau khi commit
      DATA(lv_uuid) = CONV abp_behv_cid( space ).
      TRY.
          lv_uuid = cl_uuid_factory=>create_system_uuid( )->create_uuid_x16( ).
        CATCH cx_uuid_error.
          lv_uuid = |{ sy-datum }{ sy-uzeit }|.
      ENDTRY.
      <lfs_entry>-%cid   = |{ ls_header-filename }#{ ls_header-id_doc }#{ lv_uuid }|.

      " modify start
*      <lfs_entry>-%param = VALUE #( companycode                  = ls_header-companycode
*                                    documentreferenceid          = ls_header-referencedoc
*                                    createdbyuser                = sy-uname
*                                    accountingdocumenttype       = ls_header-documenttype
*                                    documentdate                 = ls_header-documentdate
*                                    postingdate                  = ls_header-postingdate
*                                    accountingdocumentheadertext = ls_header-headertext
*                                    taxdeterminationdate         = sy-datum
*                                    businesstransactiontype      = 'RA10' ).
      <lfs_entry>-%param = VALUE #( companycode                  = ls_header-companycode
                                   documentreferenceid          = ls_header-referencedoc
                                   createdbyuser                = sy-uname
                                   accountingdocumenttype       = ls_header-documenttype
                                   documentdate                 = ls_header-documentdate
                                   postingdate                  = ls_header-postingdate
                                   accountingdocumentheadertext = ls_header-headertext
                                   taxdeterminationdate         = sy-datum
                                   businesstransactiontype      = 'RFBU' ).
      " modify end

      " Truy vấn Metadata của Posting Key để phân loại dòng (D/K/S/A)
      SELECT DISTINCT i_postingkey~postingkey,
                      i_postingkey~financialaccounttype,
                      i_postingkey~debitcreditcode
        FROM i_postingkey
               INNER JOIN
                 @ls_header-to_item AS item ON item~postingkey = i_postingkey~postingkey
        INTO TABLE @DATA(lt_postingkey).
      SORT lt_postingkey BY postingkey.

      LOOP AT ls_header-to_item INTO DATA(ls_item).

        ls_item-exchangerate /= 1000.

        IF     ls_item-amountindoumentcurrency IS INITIAL
           AND ls_item-exchangerate            IS NOT INITIAL
           AND ls_item-exchangerate            <> 0.
          ls_item-amountindoumentcurrency = ls_item-amountinlocalcurrency / ls_item-exchangerate.
        ENDIF.

        READ TABLE lt_postingkey INTO DATA(ls_pk) WITH KEY postingkey = ls_item-postingkey BINARY SEARCH.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.

        DATA(lt_curr_amounts) = fill_currency_amount( is_item         = ls_item
                                                      iv_debit_credit = ls_pk-debitcreditcode ).

        CASE ls_pk-financialaccounttype.
          WHEN 'K'.
            APPEND INITIAL LINE TO <lfs_entry>-%param-_apitems ASSIGNING FIELD-SYMBOL(<ls_ap>).
            <ls_ap> = CORRESPONDING #( ls_item MAPPING glaccountlineitem = idline supplier = account EXCEPT glaccount ).
            <ls_ap>-documentitemtext = ls_item-itemtext.
            <ls_ap>-glaccount        = COND #( WHEN ls_item-overrideglaccount IS NOT INITIAL
                                               THEN ls_item-overrideglaccount
                                               ELSE space ).
            <ls_ap>-_currencyamount  = CORRESPONDING #( lt_curr_amounts ).
            <lfs_entry>-%param-_onetimecustomersupplier = CORRESPONDING #( fill_onetime_partner(
                                                                               is_item         = ls_item
                                                                               iv_account_type = 'K' ) ).

          WHEN 'D'.
            APPEND INITIAL LINE TO <lfs_entry>-%param-_aritems ASSIGNING FIELD-SYMBOL(<ls_ar>).
            <ls_ar> = CORRESPONDING #( ls_item MAPPING glaccountlineitem = idline customer = account EXCEPT glaccount ).
            <ls_ar>-documentitemtext = ls_item-itemtext.
            <ls_ar>-glaccount        = COND #( WHEN ls_item-overrideglaccount IS NOT INITIAL
                                               THEN ls_item-overrideglaccount
                                               ELSE space ).
            <ls_ar>-_currencyamount  = CORRESPONDING #( lt_curr_amounts ).
            <lfs_entry>-%param-_onetimecustomersupplier = CORRESPONDING #( fill_onetime_partner(
                                                                               is_item         = ls_item
                                                                               iv_account_type = 'D' ) ).

          WHEN 'S' OR 'A'.
            DATA(lv_account_ext) = |{ ls_item-account ALPHA = OUT }|.

            " Nhận diện tài khoản thuế GTGT nội địa Việt Nam (133*/3331* -> MWVS/MWAS)
            IF     ( ( lv_account_ext CP '133*' AND lv_account_ext NP '1338*' ) OR lv_account_ext CP '3331*' )
               AND ls_pk-financialaccounttype = 'S'.

              APPEND INITIAL LINE TO <lfs_entry>-%param-_taxitems ASSIGNING FIELD-SYMBOL(<ls_tax>).
              <ls_tax>-glaccountlineitem  = ls_item-idline.
              <ls_tax>-taxcode            = ls_item-taxcode.
              <ls_tax>-conditiontype      = COND #( WHEN lv_account_ext CP '133*' THEN 'MWVS' ELSE 'MWAS' ).
              <ls_tax>-isdirecttaxposting = abap_true.
              <ls_tax>-_currencyamount    = CORRESPONDING #( lt_curr_amounts ).
            ELSE.
              APPEND INITIAL LINE TO <lfs_entry>-%param-_glitems ASSIGNING FIELD-SYMBOL(<ls_gl>).
              <ls_gl> = CORRESPONDING #( ls_item MAPPING glaccountlineitem = idline glaccount = account ).
              <ls_gl>-costcenter       = ls_item-costcenter.
              <ls_gl>-profitcenter     = ls_item-profitcenter.
              <ls_gl>-wbselement       = ls_item-wbselement.
              <ls_gl>-documentitemtext = ls_item-itemtext.
              <ls_gl>-_currencyamount  = CORRESPONDING #( lt_curr_amounts ).

              IF <ls_gl>-financialtransactiontype IS INITIAL.
                <ls_gl>-financialtransactiontype = '920'.
              ENDIF.

              IF ls_item-profitcenter IS NOT INITIAL.
                DATA lv_mat18 TYPE n LENGTH 18.
                lv_mat18 = ls_item-material.
                <ls_gl>-_profitabilitysupplement = VALUE #( profitcenter            = ls_item-profitcenter
                                                            costcenter              = ls_item-costcenter

                                                            customer                = ls_item-customer
                                                            customergroup           = ls_item-cusgroup
                                                            division                = ls_item-division
                                                            salesorder              = ls_item-saleorder
                                                            salesorderitem          = ls_item-saleorderitem
                                                            salesorganization       = ls_item-salesorganization


                                                            distributionchannel     = ls_item-distributionchannel
                                                            customersuppliercountry = ls_item-countrygl
                                                            plant                   = ls_item-plant
                                                            soldproduct             = lv_mat18
                                                            soldproductgroup        = ls_item-materialgroup ).
              ENDIF.

            ENDIF.
        ENDCASE.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD fill_currency_amount.
    " Quy ước Business Object (BO): Nợ (Debit) là số dương (+), Có (Credit) là số âm (-)
    DATA(lv_sign) = COND i( WHEN iv_debit_credit = 'H' THEN -1 ELSE 1 ).

    APPEND VALUE #(
        currencyrole           = '00'
        journalentryitemamount = is_item-amountindoumentcurrency * lv_sign
        currency               = is_item-transactioncurrency
        taxbaseamount          = is_item-taxbaseamount * lv_sign ) TO rt_amounts.

    " Chỉ bổ sung Local Currency (Role 10) nếu có sự khác biệt về số tiền/nội tệ
    IF is_item-amountinlocalcurrency IS NOT INITIAL
       AND is_item-amountinlocalcurrency <> is_item-amountindoumentcurrency.
      APPEND VALUE #(
          currencyrole           = '10'
          journalentryitemamount = is_item-amountinlocalcurrency * lv_sign
          exchangerate           = is_item-exchangerate
          currency               = 'VND'
          taxbaseamount          = is_item-localtaxbaseamount * lv_sign ) TO rt_amounts.
    ENDIF.
  ENDMETHOD.


  METHOD fill_onetime_partner.
    " Phân loại đối tác vãng lai: K (Supplier) ưu tiên Name1, D (Customer) dùng kịch bản ZEIV
    IF iv_account_type = 'K'.
      IF is_item-name1 IS NOT INITIAL OR is_item-name2 IS NOT INITIAL.
        rs_partner = VALUE #( name = is_item-name1 cityname = is_item-city country = is_item-country taxnumber1 = is_item-mst ).
      ELSEIF is_item-namecus1 IS NOT INITIAL.
        rs_partner = VALUE #( name = is_item-namecus1 cityname = is_item-citycus country = is_item-countrycus taxnumber1 = is_item-mstcus ).
      ENDIF.
    ELSEIF iv_account_type = 'D' AND is_item-namemotzeiv IS NOT INITIAL.
      rs_partner = VALUE #( name = is_item-namemotzeiv cityname = is_item-cityzeiv ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
