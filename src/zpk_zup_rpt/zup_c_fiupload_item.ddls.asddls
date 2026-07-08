@AbapCatalog.viewEnhancementCategory: [ #NONE ]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'FI Upload - Line Items (drill-down)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #X, sizeCategory: #S, dataClass: #TRANSACTIONAL }
define root view entity ZUP_C_FIUPLOAD_ITEM
  as select from zfi_tb_upload_i
{
  key filename                 as Filename,
  key id_doc                   as IdDoc,
  key id_line                  as IdLine,
      accountingdocumentitem   as AccountingDocumentItem,
      postingkey               as PostingKey,
      account                  as Account,
      customer                 as Customer,
      supplier                 as Supplier,
      companycodecurrency      as LocalCurrency,
      @Semantics.amount.currencyCode: 'LocalCurrency'
      amountinlocalcurrency    as AmountLC,
      transactioncurrency      as TransactionCurrency,
      @Semantics.amount.currencyCode: 'TransactionCurrency'
      amountindoumentcurrency  as AmountDC,
      costcenter               as CostCenter,
      profitcenter             as ProfitCenter,
      itemtext                 as ItemText
}
