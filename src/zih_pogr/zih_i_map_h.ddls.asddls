@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Mapping Header - Interface'
@Metadata.ignorePropagatedAnnotations: true
define view entity zih_i_map_h
  as select from zih_tb_map_h
{
  key mapping_id      as MappingId,

      process_id      as ProcessId,
      description     as Description,
      is_default      as IsDefault,
      created_at      as CreatedAt,
      created_by      as CreatedBy,
      last_changed_at as LastChangedAt,
      last_changed_by as LastChangedBy
}
