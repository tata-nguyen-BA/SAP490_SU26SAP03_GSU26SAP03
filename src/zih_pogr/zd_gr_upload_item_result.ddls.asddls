@EndUserText.label: 'GR Upload - Per-Item Result'
define abstract entity zd_gr_upload_item_result {
  gr_number : zmm_de_gr_number;
  item      : numc3;
  po_number : ebeln;
  po_item   : ebelp;
  status    : zih_de_upload_status;
  message   : abap.string(0);
}
