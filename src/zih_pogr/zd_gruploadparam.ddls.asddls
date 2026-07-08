@EndUserText.label: 'GR Upload - Action Input Parameter'
define abstract entity ZD_GRUPLOADPARAM {
  payload_json : abap.string(0);   
  testmode     : abap_boolean;      
  mapping_id   : abap.char(10);    
}
