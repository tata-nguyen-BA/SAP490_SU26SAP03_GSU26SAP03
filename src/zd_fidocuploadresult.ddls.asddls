@EndUserText.label: 'FI Doc Upload - Action Result'
define abstract entity ZD_FIDocUploadResult
{
  @EndUserText.label : 'Filename'
  Filename           : zfi_de_filename;

  @EndUserText.label : 'ID Doc'
  IdDoc              : zfi_de_id_doc;

  @EndUserText.label : 'Type'
  Type               : abap.char( 20 );

  @EndUserText.label : 'Message'
  Message            : abap.string;

  @EndUserText.label : 'Accounting Document'
  AccountingDocument : abap.char( 10 );
}
