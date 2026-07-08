@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Display log FI Item'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity ZFI_I_DIS_UP_I as select from    zfi_tb_upload_i

    left outer join zfi_tb_upload   as _AccountingDocument
      on  zfi_tb_upload_i.filename = _AccountingDocument.filename
      and zfi_tb_upload_i.id_doc   = _AccountingDocument.id_doc

  association to parent ZFI_I_DIS_UP as _header on $projection.filename = _header.filename

{
      @EndUserText.label: 'File Name'
  key zfi_tb_upload_i.filename,

      @EndUserText.label: 'ID Doc'
  key zfi_tb_upload_i.id_doc,

      @EndUserText.label: 'ID Line'
  key zfi_tb_upload_i.id_line,

      @EndUserText.label: 'Accounting Document'
      _AccountingDocument.accountingdocument,

      @EndUserText.label: 'Company Code'
      _AccountingDocument.companycode          as Companycode,

      @EndUserText.label: 'Document Type'
      _AccountingDocument.documenttype         as Documenttype,

      @EndUserText.label: 'Currency'
      _AccountingDocument.currency             as Currency,

      @EndUserText.label: 'Exchange Rate'
      _AccountingDocument.exchangerate         as Exchangerate,

      @EndUserText.label: 'Reference Document'
      _AccountingDocument.referencedoc         as Referencedoc,

      @EndUserText.label: 'Header Reference 1'
      _AccountingDocument.headerref1           as Headerref1,

      @EndUserText.label: 'User Description'
      @UI.hidden: true
      _header.UserDescription,

      @EndUserText.label: 'Posting Key'
      zfi_tb_upload_i.postingkey,

      @EndUserText.label: 'Account'
      zfi_tb_upload_i.account,

      @EndUserText.label: 'Main Asset Number'
      zfi_tb_upload_i.mainassetnumber,

      @EndUserText.label: 'Sub Asset Number'
      zfi_tb_upload_i.subassetnumber,

      @EndUserText.label: 'Special GL Indicator'
      zfi_tb_upload_i.specialglaccount,

      @EndUserText.label: 'Asset Transaction Type'
      zfi_tb_upload_i.assettransactiontype,

      @EndUserText.label: 'Company Code Currency'
      zfi_tb_upload_i.companycodecurrency,

      @EndUserText.label: 'Amount in Local Currency'
      @Semantics.amount.currencyCode: 'companycodecurrency'
      zfi_tb_upload_i.amountinlocalcurrency,

      @EndUserText.label: 'Transaction Currency'
      zfi_tb_upload_i.transactioncurrency,

      @EndUserText.label: 'Amount in Document Currency'
      @Semantics.amount.currencyCode: 'transactioncurrency'
      zfi_tb_upload_i.amountindoumentcurrency,

      @EndUserText.label: 'Tax Base Amount (Doc Cur)'
      @Semantics.amount.currencyCode: 'transactioncurrency'
      zfi_tb_upload_i.taxbaseamount,

      @EndUserText.label: 'Tax Base Amount (Local Cur)'
      @Semantics.amount.currencyCode: 'transactioncurrency'
      zfi_tb_upload_i.localtaxbaseamount,

      @EndUserText.label: 'Assignment'
      zfi_tb_upload_i.assignment,

      @EndUserText.label: 'Business Area'
      zfi_tb_upload_i.businessarea,

      @EndUserText.label: 'Cost Center'
      zfi_tb_upload_i.costcenter,

      @EndUserText.label: 'Profit Center'
      zfi_tb_upload_i.profitcenter,

      @EndUserText.label: 'Internal Order'
      zfi_tb_upload_i.internalorder,

      @EndUserText.label: 'Asset Value Date'
      zfi_tb_upload_i.assetvaluedate,

      @EndUserText.label: 'Item Text'
      zfi_tb_upload_i.itemtext,

      @EndUserText.label: 'Override GL Account'
      zfi_tb_upload_i.overrideglaccount,

      @EndUserText.label: 'Tax Code'
      zfi_tb_upload_i.taxcode,

      @EndUserText.label: 'Segment'
      zfi_tb_upload_i.segment,

      @EndUserText.label: 'Payment Terms'
      zfi_tb_upload_i.paymentterms,

      @EndUserText.label: 'Payment Block Reason'
      zfi_tb_upload_i.paymentblockreason,

      @EndUserText.label: 'Payment Method'
      zfi_tb_upload_i.paymentmethod,

      @EndUserText.label: 'Contract Number'
      zfi_tb_upload_i.contractnumber,

      @EndUserText.label: 'Contract Type'
      zfi_tb_upload_i.contracttype,

      @EndUserText.label: 'House Bank'
      zfi_tb_upload_i.housebank,

      @EndUserText.label: 'Bank Account ID'
      zfi_tb_upload_i.bankaccountid,

      @EndUserText.label: 'Invoice Ref. Number'
      zfi_tb_upload_i.invoicerefnum,

      @EndUserText.label: 'Invoice Ref. Fiscal Year'
      zfi_tb_upload_i.invoicefiscalyear,

      @EndUserText.label: 'Invoice Ref. Line Item'
      zfi_tb_upload_i.invoicereflineitem,

      @EndUserText.label: 'Purchasing Doc. No.'
      zfi_tb_upload_i.purchasingno,

      @EndUserText.label: 'Purchasing Doc. Item'
      zfi_tb_upload_i.purchasingitem,

      @EndUserText.label: 'Baseline Date'
      zfi_tb_upload_i.baselinedate,

      @EndUserText.label: 'Value Date'
      zfi_tb_upload_i.valuedate,

      @EndUserText.label: 'Sales Order Number'
      zfi_tb_upload_i.saleorder,

      @EndUserText.label: 'Sales Order Item'
      zfi_tb_upload_i.saleorderitem,

      @EndUserText.label: 'Reference 1'
      zfi_tb_upload_i.ref1,

      @EndUserText.label: 'Reference 3'
      zfi_tb_upload_i.ref3,

      @EndUserText.label: 'Long Text'
      zfi_tb_upload_i.longtext,

      @EndUserText.label: 'Material'
      zfi_tb_upload_i.material,

      @EndUserText.label: 'Unit of Measure'
      zfi_tb_upload_i.unit,

      @EndUserText.label: 'Name 1 (Mã vãng lai)'
      zfi_tb_upload_i.name1,

      @EndUserText.label: 'Name 2 (Mã vãng lai)'
      zfi_tb_upload_i.name2,

      @EndUserText.label: 'City (Mã vãng lai)'
      zfi_tb_upload_i.city,

      @EndUserText.label: 'Country (Mã vãng lai)'
      zfi_tb_upload_i.country,

      @EndUserText.label: 'VAT Reg. No. (Mã vãng lai)'
      zfi_tb_upload_i.vatregno,

      @EndUserText.label: 'Quantity'
      @Semantics.quantity.unitOfMeasure: 'unit'
      zfi_tb_upload_i.quantity,

      @EndUserText.label: 'Customer'
      zfi_tb_upload_i.customer,

      @EndUserText.label: 'Supplier'
      zfi_tb_upload_i.supplier,

      @EndUserText.label: 'Alternative Payee'
      zfi_tb_upload_i.alternativepayee,

      @EndUserText.label: 'VAT Number'
      zfi_tb_upload_i.mst,

      @EndUserText.label: 'Name 1 (Individual Payee)'
      zfi_tb_upload_i.hotennc1,

      @EndUserText.label: 'Name 2 (Individual Payee)'
      zfi_tb_upload_i.hotennc2,

      @EndUserText.label: 'Customer Group'
      zfi_tb_upload_i.cusgroup,

      @EndUserText.label: 'Division'
      zfi_tb_upload_i.division,

      @EndUserText.label: 'Distribution Channel'
      zfi_tb_upload_i.distributionchannel,

      @EndUserText.label: 'Sales Office'
      zfi_tb_upload_i.salesoffice,

      @EndUserText.label: 'Sales Employee'
      zfi_tb_upload_i.salesemployee,

      @EndUserText.label: 'Sales Group'
      zfi_tb_upload_i.salesgroup,

      @EndUserText.label: 'Material Group'
      zfi_tb_upload_i.materialgroup,

      @EndUserText.label: 'Dòng sản phẩm'
      zfi_tb_upload_i.dongsanpham,

      @EndUserText.label: 'Loại hình sản xuất'
      zfi_tb_upload_i.loaihinhsanpham,

      @EndUserText.label: 'Product'
      zfi_tb_upload_i.product,

      @EndUserText.label: 'Material Group Level 1'
      zfi_tb_upload_i.materialgrouplevel1,

      @EndUserText.label: 'Material Group Level 2'
      zfi_tb_upload_i.materialgrouplevel2,

      @EndUserText.label: 'Payer'
      zfi_tb_upload_i.payer,

      @EndUserText.label: 'Order ID'
      zfi_tb_upload_i.orderid,

      _header
}
