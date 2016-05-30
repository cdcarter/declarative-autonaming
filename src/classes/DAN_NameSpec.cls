public class DAN_NameSpec implements DAN.INameSpec {
    public List<DAN.NameSpecResult> autoname(List<DAN.NameSpecRequest> reqs) {
		List<DAN.NameSpecResult> results = new List<DAN.NameSpecResult>();
        for(DAN.NameSpecRequest req : reqs) {
            DAN.NameSpecResult res = new DAN.NameSpecResult();
            res.objectId = req.objectId;
            res.name = 'You have been autonamed!';
            results.add(res);
        }
        return results;
    }
}