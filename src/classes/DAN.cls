global class DAN {
    global static Boolean inTrigger = false;
    
    // core data types for the INameSpec interface
    global class NameSpecRequest {
        public String nameSpec;
        public Id objectId;
        public SObject instant;
        global NameSpecRequest(Autonaming_Rule__mdt rule, SObject obj) {
            this.nameSpec = rule.Name_Spec__c; this.objectId = obj.Id; this.instant = obj;
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
    
    private static Map<String,List<Database.SaveResult>> renameAndUpdate(List<SObject> objects) {
        Map<String,List<Database.SaveResult>> retval = new Map<String,List<Database.SaveResult>>();
        Map<Autonaming_Rule__mdt,List<SObject>> mdtMap = getMDTs(objects);
        Map<String,List<SObject>> results = new Map<String,List<SObject>>();
        for(Autonaming_Rule__mdt rule : mdtMap.keySet()) {
            if(!results.containsKey(rule.Object__c)) {
                results.put(rule.Object__c,new List<SObject>());
            }
            results.get(rule.Object__c).addAll(getResults(rule,mdtMap.get(rule)));
        }
        for(String objType : results.keySet()) {
            retval.put(objType,Database.update(results.get(objType)));
        }
        return retval;
    }
    
    private static Map<Autonaming_Rule__mdt,List<SObject>> getMDTs(List<SObject> objs) {
        Map<String, List<SObject>> objectMap = new Map<String, List<SObject>>();
    	Map<String, Autonaming_Rule__mdt> mdtMap = new Map<String, Autonaming_Rule__mdt>();
        Set<String> objNames = new Set<String>();
        for(SObject obj : objs) {
            objNames.add(obj.getSObjectType().getDescribe().getName());
        }
        for(Autonaming_Rule__mdt rule : [SELECT Name_Spec__c, NameSpec_Processor__c, Naming_Result_Field__c, Object__c FROM Autonaming_Rule__mdt WHERE Active__c = true AND Object__c IN :objNames]) {
            objectMap.put(rule.Object__c,new List<SObject>());
            mdtMap.put(rule.Object__c,rule);
        }
        for(SObject obj : objs) {
            String objName = obj.getSObjectType().getDescribe().getName();
            if(objectMap.containsKey(objName)) {
                objectMap.get(objName).add(obj);
            }
        }
        Map<Autonaming_Rule__mdt,List<SObject>> result = new Map<Autonaming_Rule__mdt,List<SObject>>();
        for(String obj : objNames) {
            result.put(mdtMap.get(obj),objectMap.get(obj));
        }
        return result;
    }
    
    private static List<SObject> getResults(Autonaming_Rule__mdt rule,List<SObject> objs) {
        Type processorType = Type.forName(rule.NameSpec_Processor__c);
		INameSpec processor = (INameSpec)processorType.newInstance();
        List<NameSpecRequest> reqs = reqsFromObjects(rule,objs);
        List<NameSpecResult> processorResults = processor.autoname(reqs);
        
        SObjectType objType = Schema.getGlobalDescribe().get(rule.Object__c);
        List<SObject> result = new List<SObject>();
        for(NameSpecResult res : processorResults) {
            SObject obj = objType.newSObject();
            obj.put('Id', res.objectId);
            obj.put(rule.Naming_Result_Field__c, res.name);
            result.add(obj);
        }
        return result;
    }
    
    private static List<NameSpecRequest> reqsFromObjects(Autonaming_Rule__mdt rule, List<SObject> objs) {
        List<NameSpecRequest> reqs = new List<NameSpecRequest>();
        for(SObject obj : objs) {
            NameSpecRequest req = new NameSpecRequest(rule,obj);
            reqs.add(req);
        }
        return reqs;
    }
}