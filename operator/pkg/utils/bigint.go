package utils

import (
	"fmt"
	"math/big"
)

// MustSetString creates a big.Int from string, panicking on error
func MustSetString(s string) *big.Int {
	result, ok := new(big.Int).SetString(s, 10)
	if !ok {
		panic(fmt.Sprintf("invalid big.Int string: %s", s))
	}
	return result
}
