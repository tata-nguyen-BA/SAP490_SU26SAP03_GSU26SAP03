@EndUserText.label: 'Mapping Field'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
define view entity zih_c_map_i
  as select from zih_i_map_i
{
  key MappingId,
  key TargetField,
      Seq,
      FieldLabel,
      BapiStructure,
      BapiField,
      SourceHeader,
      IsRequired
}
