global class DAN {
    global static Boolean inTrigger = false;
    
    // core data types for the INameSpec interface
    global class NameSpecRequest {
        public String nameSpec;
        public Id objectId;
        public SObject instant;
        global NameSpecRequest(NameRule rule, SObject obj) {
            this.nameSpec = rule.nameSpec; this.objectId = obj.Id; this.instant = obj;
        }
    }
    global class NameSpecResult {
        public String name;
        public Id objectId;
    }
    
    // core interface for naming implementations to implement
    global interface INameSpec {
        List<DAN.NameSpecResult> autoname(List<DAN.NameSpecRequest> reqs);
    }
    
    // only exported method for triggers to use
    global static void handleAfterTrigger(List<SObject> objects) {
       	if(!DAN.inTrigger){
        	DAN.inTrigger = true;
			renameAndUpdate(objects);
            DAN.inTrigger = false;
        }
    } 
    
    @testVisible
    private static Map<String,List<Database.SaveResult>> renameAndUpdate(List<SObject> objects) {
        Map<String,List<Database.SaveResult>> retval = new Map<String,List<Database.SaveResult>>();
        Map<NameRule,List<SObject>> ruleMap = getObjectsByRule(objects);
        Map<String,List<SObject>> results = new Map<String,List<SObject>>();
        for(NameRule rule : ruleMap.keySet()) {
            if(!results.containsKey(rule.obj)) {
                results.put(rule.obj,new List<SObject>());
            }
            results.get(rule.obj).addAll(getResults(rule,ruleMap.get(rule)));
        }
        for(String objType : results.keySet()) {
            retval.put(objType,Database.update(results.get(objType)));
        }
        return retval;
    }
    
    @testVisible
    private static Map<NameRule,List<SObject>> getObjectsByRule(List<SObject> objs) {
        Map<String, List<SObject>> objectMap = new Map<String, List<SObject>>();
    	  Map<String, NameRule> ruleMap = new Map<String, NameRule>();
        Set<String> objNames = new Set<String>();
        for(SObject obj : objs) {
            objNames.add(obj.getSObjectType().getDescribe().getName());
        }
        for(NameRule rule : getRules(objNames)) {
          objectMap.put(rule.obj,new List<SObject>());
          ruleMap.put(rule.obj,rule);
        }
        for(SObject obj : objs) {
            String objName = obj.getSObjectType().getDescribe().getName();
            if(objectMap.containsKey(objName)) {
                objectMap.get(objName).add(obj);
            }
        }
        Map<NameRule,List<SObject>> result = new Map<NameRule,List<SObject>>();
        for(String obj : objNames) {
            result.put(ruleMap.get(obj),objectMap.get(obj));
        }
        return result;
    }
    
    @testVisible
    private static List<NameRule> getRules(Set<String> objnames) {
      List<NameRule> result = new List<NameRule>();
      if(Test.isRunningTest()) {
        NameRule rule = new NameRule();
        rule.obj = 'Account';rule.nameField = 'Name';rule.nameSpec='test';rule.nameSpecProcessor='DAN_NameSpec'; 
        result.add(rule);
      } else {
        for(Autonaming_Rule__mdt rule : [SELECT Active__c, Name_Spec__c, NameSpec_Processor__c, Naming_Result_Field__c, Object__c FROM Autonaming_Rule__mdt WHERE Active__c = true AND Object__c IN :objNames]) {
          result.add(new NameRule(rule));
        }
      }
      return result;
    }
    
    @testVisible
    private static List<SObject> getResults(NameRule rule,List<SObject> objs) {
        Type processorType = Type.forName(rule.nameSpecProcessor);
		    INameSpec processor = (INameSpec)processorType.newInstance();
        List<NameSpecRequest> reqs = reqsFromObjects(rule,objs);
        List<NameSpecResult> processorResults = processor.autoname(reqs);
        
        SObjectType objType = Schema.getGlobalDescribe().get(rule.obj);
        List<SObject> result = new List<SObject>();
        for(NameSpecResult res : processorResults) {
            SObject obj = objType.newSObject();
            obj.put('Id', res.objectId);
            obj.put(rule.nameField, res.name);
            result.add(obj);
        }
        return result;
    }
    
    @testVisible
    private static List<NameSpecRequest> reqsFromObjects(NameRule rule, List<SObject> objs) {
        List<NameSpecRequest> reqs = new List<NameSpecRequest>();
        for(SObject obj : objs) {
            NameSpecRequest req = new NameSpecRequest(rule,obj);
            reqs.add(req);
        }
        return reqs;
    }
    
    global class NameRule {
      public Boolean active;
      public String obj;
      public String nameField;
      public String nameSpec;
      public String nameSpecProcessor;
      public NameRule() {}
      public NameRule(Autonaming_Rule__mdt rule) {
        active = rule.Active__c; obj = rule.Object__c; nameField = rule.Naming_Result_Field__c;
        nameSpec = rule.Name_Spec__c; nameSpecProcessor = rule.NameSpec_Processor__c;
      }
    }
}
