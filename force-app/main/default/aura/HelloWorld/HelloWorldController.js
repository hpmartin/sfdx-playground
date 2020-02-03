({
    doInit : function(component, event, helper) {
        var action = component.get("c.findUserName");
        action.setParams({ });
        action.setCallback(this, function(response){
            var userData = response.getReturnValue();
            component.set("v.greeting", userData.Name+' your last login was on '+userData.LastLogin);
        });
        $A.enqueueAction(action);
    }
})