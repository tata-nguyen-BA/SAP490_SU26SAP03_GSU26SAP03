@AbapCatalog.viewEnhancementCategory: [ #NONE ]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'FI Upload - Item Count + Debit Amount per Doc'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #X, sizeCategory: #S, dataClass: #TRANSACTIONAL }
define view entity ZUP_P_FIUPLOAD_ITEMCNT
  as select from zfi_tb_upload_i
{
  key filename,
  key id_doc,
      count( * )          as LineCount,
      companycodecurrency as LocalCurrency,
      @Semantics.amount.currencyCode: 'LocalCurrency'
      sum( case
             when postingkey = '40' or postingkey = '01'
               or postingkey = '21' or postingkey = '70'
             then amountinlocalcurrency
             else cast( 0 as abap.curr(23,2) )
           end )          as TotalAmountLC
}
group by
  filename,
  id_doc,
  companycodecurrency
