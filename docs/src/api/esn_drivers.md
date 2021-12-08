# ESN Drivers
```@docs
    RNN
    MRNN
    GRU
```
The ```GRU``` driver also provides the user the choice of the possible variant:
```@docs
    FullyGated
    Variant1
    Variant2
    Variant3
    Minimal
```
Please refer to the original papers for more detail about these architectures.

The states are created using the following function
```@docs
    create_states
```