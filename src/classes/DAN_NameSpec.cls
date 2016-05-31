public class DAN_NameSpec implements DAN.INameSpec {
  public List<DAN.NameSpecResult> autoname(List<DAN.NameSpecRequest> reqs) {
    List<DAN.NameSpecResult> results = new List<DAN.NameSpecResult>();
    Set<Id> recordsToRename = new Set<id>();
    Set<String> fields = new Set<String>();
    for(DAN.NameSpecRequest req : reqs) {
      recordsToRename.add(req.objectId);
      fields.addAll(getFieldNamesFromSpec(req.nameSpec));
    }
    List<String> fieldsToQuery = new List<String>(fields);
    // currently taking advantage of the fact that DAN batches NameSpecRequests by object type...
    String query = 'SELECT ' + String.join(fieldsToQuery,',') + ' FROM ' + reqs[0].objectType.getDescribe().getName() +' WHERE Id IN :recordsToRename';
    Map<Id,SObject> objects = new Map<Id,SObject>(Database.query(query));

    for(DAN.NameSpecRequest req : reqs) {
      DAN.NameSpecResult res = new DAN.NameSpecResult();
      res.objectId = req.objectId;
      res.name = processName(req,objects.get(req.objectId));
      results.add(res);
    }
    return results;
  }

  private static string openToken = '{!';
  private static string closeToken = '}';


  public static set<string> getFieldNamesFromSpec(String spec) {
      set<string> setStrField = new set<string>();
      if (!string.isBlank(spec)) {
        Pattern namePattern = Pattern.compile('\\{![^\\{!]*\\}');
        Matcher nameMatcher = namePattern.matcher(spec);

          while (nameMatcher.find()) {
              string strField = spec.substring(nameMatcher.start() + openToken.length(), nameMatcher.end()-closeToken.length());
              setStrField.add(strField.trim().toLowerCase());
          }
      }
      return setStrField;
  }

  private String processName(DAN.NameSpecRequest request, SObject obj) {
    String result = request.nameSpec;
    Pattern namePattern = Pattern.compile('\\{![^\\{!]*\\}');
    Matcher nameMatcher = namePattern.matcher(request.nameSpec);

    while (nameMatcher.find()) {
      String field = request.nameSpec.substring(nameMatcher.start() + openToken.length(), nameMatcher.end()-closeToken.length());
      List<String> splitField = (field.split('\\.',0));
      String fieldName = splitField[splitField.size()-1];
      splitField.remove(splitField.size()-1);
      SObject thisObj = obj;
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