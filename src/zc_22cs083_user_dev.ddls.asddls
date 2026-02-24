@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Child Consumption View'
@Metadata.allowExtensions: true
define view entity ZC_22CS083_USER_DEV
  as projection on ZI_22CS083_USER_DEV
{
  key EmpID,
  key DevID,
  key SerialNo,
      ObjectType,
      ObjectName,
      _User : redirected to parent ZC_22CS083_USER
}
