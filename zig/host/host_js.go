//go:build js

package host

import "errors"

func Run(libName string) error { return errors.ErrUnsupported }
func Main(libName string)      { panic(errors.ErrUnsupported) }
