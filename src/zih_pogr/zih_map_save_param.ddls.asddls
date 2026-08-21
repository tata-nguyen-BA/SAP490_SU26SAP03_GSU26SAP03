@EndUserText.label: 'Mapping - Save Parameter'
define abstract entity ZIH_MAP_SAVE_PARAM {
  mapping_id   : abap.char(10);
  process_id   : abap.char(10);
  description  : abap.char(60);
  payload_json : abap.string(0);
  user_email   : abap.string(0);
}
