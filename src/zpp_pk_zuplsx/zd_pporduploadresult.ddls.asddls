@EndUserText.label: 'PP Order Upload - Action Result'
define abstract entity ZD_PPOrdUploadResult
{
  ClientRowId     : abap.int4;
  IdDoc           : abap.char( 50 );
  Type            : abap.char( 20 );
  Message         : abap.string( 0 );
  ProductionOrder : abap.char( 12 );
}
