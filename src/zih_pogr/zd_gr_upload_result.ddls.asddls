@EndUserText.label: 'GR Upload - Action Output Result'

define abstract entity zd_gr_upload_result {
  batch_id      : zih_de_batch_id;    
  total_count   : abap.int4;
  success_count : abap.int4;
  error_count   : abap.int4;
  status        : zih_de_upload_status; 
  message       : abap.string(0);
}
