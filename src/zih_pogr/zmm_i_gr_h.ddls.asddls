@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'GR Upload - Header Interface'
@Metadata.ignorePropagatedAnnotations: true
define root view entity zmm_i_gr_h
  as select from zmm_tb_gr_h

  composition [0..*] of zmm_i_gr_i as _items
{
  key gr_number             as GrNumber,
  batch_id                  as BatchId,
  document_date             as DocumentDate,
  movement_type             as MovementType,
  testmode                  as Testmode,
  status                    as Status,
   case status
    when 'S' then 3
    when 'E' then 1
    else 2
  end                           as StatusCriticality,
  message                   as Message,
  material_document         as MaterialDocument,
  mat_doc_year              as MaterialDocumentYear,
  log_handle                as LogHandle,
  @Semantics.systemDateTime.createdAt: true
  created_at                as CreatedAt,
  @Semantics.user.createdBy: true
  created_by                as CreatedBy,
  @Semantics.systemDateTime.lastChangedAt: true
  last_changed_at           as LastChangedAt,
  @Semantics.user.lastChangedBy: true
  last_changed_by           as LastChangedBy,
  @Semantics.systemDateTime.localInstanceLastChangedAt: true
  local_last_changed_at     as LocalLastChangedAt,
  _items
}
