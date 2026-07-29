@EndUserText.label: 'GR Upload - Item'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

define view entity zmm_c_gr_i
  as projection on zmm_i_gr_i
{
  key GrNumber,
  key Item,

  PoNumber,
  PoItem,
  PoItemText,
  Material,
  Plant,
  Batch,

  ReceiveQty,
  Unit,
  StorageLocation,
  OrderQty,
  OpenQty,

  Status,
  StatusCriticality,
  Message,
  MaterialDocument,
  MaterialDocumentItem,
  MaterialDocumentYear,

  _header : redirected to parent zmm_c_gr_h
}
