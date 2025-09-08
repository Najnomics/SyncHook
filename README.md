# SyncHook
SyncHook maintains synchronized pool states across chains using an Actively Validated Service (AVS) and Across Protocol for liquidity movement. The hook retrieves global pool state from the AVS in beforeSwap, adjusts swap parameters for consistency, updates the AVS with new state information in afterSwap, and uses Across to redistribute assets .
