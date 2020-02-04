/**
 @description Controlador del Lighning Component Hello world, presenta el nombre y el last login del usuario
 */
public without sharing class HelloWorldApexController {
	
    @auraEnabled
    public static UserData findUserName(){
        User us = [Select Name, LastLoginDate from User where Id = :UserInfo.getUserId()];        
        UserData ud = new UserData();
        ud.Name = us.Name;
        ud.LastLogin = us.LastLoginDate.format();
        return ud;
    }
    
    /**
     * Pojo para la comunicación con el apex component
     */
    public class UserData {
        @AuraEnabled public String Name { get; set; }
        @AuraEnabled public String LastLogin { get; set; }
    }
}