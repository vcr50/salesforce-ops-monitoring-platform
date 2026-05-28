public with sharing class SiteRegisterController {
    public String username {get; set;}
    public String email {get; set;}
    public String password {get; set;}
    public String confirmPassword {get; set;}
    public String communityNickname {get; set;}
    public SiteRegisterController() {}
    public PageReference registerUser() { return null; }
}