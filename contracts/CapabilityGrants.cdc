access(all) contract CapabilityGrants {

    pub  struct Link {
        pub var type: Type
        pub var capabilityPath: CapabilityPath

        init(type: Type, capabilityPath: CapabilityPath){
            self.type = type
            self.capabilityPath = capabilityPath
        }
    }

    pub resource AccountManager{
        access(contract) var accountCapability: Capability<&AuthAccount>
        access(contract) var capabilities: {Type:[Capability]}
        access(contract) var appGrants: [Capability]
        priv var accountOwnerCount: Int 
        priv var accountOwnerLimit: Int 

        pub fun getAppGrants():[Capability]{
            return self.appGrants
        }
        pub fun getCapabilities(t: Type):[Capability]?{
            return self.capabilities[t]
        }

        pub fun grantCapabilityToApp(cap: Capability){
            self.appGrants.append(cap)
        }

        pub fun revokeCapabilityFromApp(cap: Capability){
            //need to loop here to find capability
            self.appGrants.remove(at: self.appGrants.firstIndex(of: cap)!)
        }

        pub fun storeResourceWithLinks(_ r: @AnyResource, to: StoragePath, links: [Link] ){
            var acct = self.accountCapability.borrow()!
            acct.save(<-r, to: to)
            for l in links {
                //we need link with new types ( commented out below ) 

                //acct.link(l.type, l.capabilityPath, target: to)
                
                self.capabilities[l.type]!.append(acct.getCapability(l.capabilityPath))
            }
        }

        access(contract) fun getAppManager(): @AppManager{
            pre{
                self.accountOwnerCount < self.accountOwnerLimit: "only there can be one account manager"
            }
            return <- create AppManager(self.accountCapability)
        }
        init(_ accountCapability: Capability<&AuthAccount>, accountOwnerLimit: Int){
            self.accountCapability = accountCapability
            self.capabilities={}
            self.appGrants=[]
            self.accountOwnerLimit = accountOwnerLimit
            self.accountOwnerCount = 0
        }

    }

    pub fun createChildAccount(payer: AuthAccount, accountOwnerLimit: Int):@AccountOwner{
        //create account
        var acc = AuthAccount(payer: payer)
        acc.linkAccount(/private/account)
        var accCap = acc.getCapability<&AuthAccount>(/private/account)

        //create account manager 
        var accountManager <- create AccountManager(accCap, accountOwnerLimit: accountOwnerLimit)

        //save to account 
        acc.save(<-accountManager, to: /storage/AccountManager)
        
        //return first remote manager 
        return <-create AccountOwner(accCap)
    }

    pub resource AppManager{
        access(contract) var accountCapability: Capability<&AuthAccount>

        pub fun appGrants():[Capability]{
            return self.accountCapability.borrow()!.borrow<&AccountManager>(from: /storage/AccountManager)!.getAppGrants()
        }

        pub fun storeResourceWithLinks(_ r: @AnyResource, to: StoragePath, links: [Link] ){
            return self.accountCapability.borrow()!.borrow<&AccountManager>(from: /storage/AccountManager)!.storeResourceWithLinks(<-r, to:to, links:links)
        }

        init(_ accountCapability: Capability<&AuthAccount>){
            self.accountCapability = accountCapability
        }
    }
    
    pub resource AccountOwner{
            access(contract) var accountCapability: Capability<&AuthAccount>

            pub fun getAccountManager(): &AccountManager{
                return self.accountCapability.borrow()!.borrow<&AccountManager>(from: /storage/AccountManager)!
            }

            init(_ accountCapability: Capability<&AuthAccount>){
                self.accountCapability = accountCapability
            }
    }

}

