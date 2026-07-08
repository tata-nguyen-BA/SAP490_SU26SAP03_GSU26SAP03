@EndUserText.label: 'GR Upload - Header'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true


define root view entity zmm_c_gr_h
  provider contract transactional_query
  as projection on zmm_i_gr_h
{
  key GrNumber,
  BatchId,
  DocumentDate,
  MovementType,
  Testmode,
  Status,
  StatusCriticality,
  Message,
  MaterialDocument,
  MaterialDocumentYear,
  CreatedAt,
  CreatedBy,
  LastChangedAt,
  LastChangedBy,
  LocalLastChangedAt,

  _items : redirected to composition child zmm_c_gr_i
}
