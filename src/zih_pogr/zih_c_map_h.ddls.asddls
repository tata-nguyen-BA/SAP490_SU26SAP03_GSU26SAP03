@EndUserText.label: 'Mapping Configuration'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
define view entity zih_c_map_h
  as select from zih_i_map_h
{
  key MappingId,
      ProcessId,
      Description,
      IsDefault,
      CreatedAt,
      CreatedBy,
      LastChangedAt,
      LastChangedBy
}
