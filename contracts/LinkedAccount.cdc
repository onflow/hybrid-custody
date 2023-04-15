pub contract interface LinkedAccount {
    pub resource interface Account {
        pub fun getPublicCap(path: PublicPath, type: Type): Capability?
        pub fun getPrivateCap(path: PrivatePath, type: Type): Capability?
        pub fun getCapability(path: CapabilityPath, type: Type): Capability?
        pub fun check(): Bool
        pub fun getAccountAddress(): Address
    }
}