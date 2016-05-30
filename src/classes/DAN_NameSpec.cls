public class DAN_NameSpec implements DAN.INameSpec {
  public List<DAN.NameSpecResult> autoname(List<DAN.NameSpecRequest> reqs) {
    List<DAN.NameSpecResult> results = new List<DAN.NameSpecResult>();
    for(DAN.NameSpecRequest req : reqs) {
      DAN.NameSpecResult res = new DAN.NameSpecResult();
      res.objectId = req.objectId;
      res.name = processName(req);
      results.add(res);
    }
    return results;
  }
  
  private static string openToken = '{!';
  private static string closeToken = '}';
  
  @testVisible
  private String processName(DAN.NameSpecRequest request) {
    String result = request.nameSpec;
    Pattern namePattern = Pattern.compile('\\{![^\\{!]*\\}'); 
    Matcher nameMatcher = namePattern.matcher(request.nameSpec);
    
    while (nameMatcher.find()) {
      String field = request.nameSpec.substring(nameMatcher.start() + openToken.length(), nameMatcher.end()-closeToken.length());
      List<String> splitField = (field.split('\\.',0));
      String fieldName = splitField[splitField.size()-1];
      splitField.remove(splitField.size()-1);
      SObject thisObj = request.instant;
      if(thisObj != null) {
        for(String parentObj : splitField) {
          thisObj = thisObj.getSObject(parentObj);
        }
      }
      
      String val = getFieldValue(thisObj, fieldName, request);
      
      // add back the {}'s for string substitution
      field = openToken + field + closeToken;
      if (val == null) {   
        // eat potential trailing space
        result = result.replace(field + ' ', '');
        // eat potential leading space
        result = result.replace(' ' + field, '');
      }
      result = result.replace(field, val == null ? '' : val);
    }
    return result;
  }
  
  @testVisible
  public static string getFieldValue(sObject obj, string fieldName, DAN.NameSpecRequest name) {
    if (obj==null) return null;
    string result = '';
    
    Object val = obj.get(fieldName.trim());
    if (val==null)
    return null;
    
    Schema.DisplayType dt = obj.getSObjectType().getDescribe().fields.getMap().get(fieldName).getDescribe().getType();
    //If this is a Date or DateTime field, use the specified formatting if there is one
    if (dt == Schema.DisplayType.Date || dt == Schema.DisplayType.DateTime) {
      DateTime d = (DateTime) val;
      string dateFormat = 'MM/dd/YYYY';
      //if this was a date, use the GMT time zone so we don't end up on a different date
      if (dt == Schema.DisplayType.Date) {
        result = d.formatGmt(dateFormat);
      } else {
        result = d.format(dateFormat);
      }
    } else if (dt == Schema.DisplayType.Currency) {
      result = string.format('{0,Number,Currency}',new List<String>{String.valueOf(val)});
    } else {
      result = String.valueOf(val);
    }
    return result;
  }

}
