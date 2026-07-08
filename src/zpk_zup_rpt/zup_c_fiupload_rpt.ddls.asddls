@AbapCatalog.viewEnhancementCategory: [ #NONE ]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'FI Upload Analytics Report'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #X, sizeCategory: #S, dataClass: #TRANSACTIONAL }
define root view entity ZUP_C_FIUPLOAD_RPT
  as select from zfi_tb_upload             as _Hdr
    left outer join ZUP_P_FIUPLOAD_ITEMCNT as _Cnt on  _Cnt.filename = _Hdr.filename
                                                   and _Cnt.id_doc   = _Hdr.id_doc
{
  key _Hdr.filename           as Filename,
  key _Hdr.id_doc             as IdDoc,
      _Hdr.accountingdocument as AccountingDocument,
      _Hdr.fiscalyear         as FiscalYear,
      _Hdr.companycode        as CompanyCode,
      _Hdr.documenttype       as DocumentType,
      _Hdr.documentdate       as DocumentDate,
      _Hdr.postingdate        as PostingDate,
      _Hdr.currency           as Currency,
      _Hdr.headertext         as HeaderText,
      coalesce( _Cnt.LineCount, 0 ) as LineCount,
      _Cnt.LocalCurrency      as LocalCurrency,
      @Semantics.amount.currencyCode: 'LocalCurrency'
      _Cnt.TotalAmountLC      as TotalAmountLC,
      _Hdr.ispst              as IsPosted,
      _Hdr.pst_date           as PstDate,
      _Hdr.pst_user           as PstUser,
      _Hdr.upd_date           as UpdDate,
      _Hdr.upd_user           as UpdUser
}
