@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Mapping Field - Interface'
@Metadata.ignorePropagatedAnnotations: true
define view entity zih_i_map_i
  as select from zih_tb_map_i
{
  key mapping_id     as MappingId,
  key target_field   as TargetField,

      seq            as Seq,
      field_label    as FieldLabel,
      bapi_structure as BapiStructure,
      bapi_field     as BapiField,
      source_header  as SourceHeader,
      is_required    as IsRequired
}
