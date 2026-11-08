//go:build !js

// Package sqlite registers the official `plugins/sqlite` Go API into `zig/host`.
//
// Import with `_ "github.com/egoist/mygo/zig/host/sqlite"` in Zig apps that need
// a local database. `mygo build` / `mygo dev` pick up `mygo-plugin.json` and
// ship libmygo-sqlite3 among the app resources. Args and results cross the FFI
// as JSON (same shape as the TypeScript plugin client).
package sqlite

import (
	"context"
	"encoding/json"
	"errors"
	"sync"
	"sync/atomic"

	plug "github.com/egoist/mygo/plugins/sqlite"
	"github.com/egoist/mygo/zig/host"
)

func init() {
	host.SQLiteDispatch = dispatch
}

var (
	dbsMu sync.Mutex
	dbs   = map[uintptr]*plug.DB{}
	nextID atomic.Uintptr
)

func dispatch(op, a0, a1, a2, a3 uintptr) uintptr {
	_ = a2
	_ = a3
	if op != host.HostOpSQLite {
		host.SetError(errors.New("zighost: unknown sqlite op"))
		return ^uintptr(0)
	}
	switch a0 {
	case host.SQLiteOpen:
		return open(a1)
	case host.SQLiteClose:
		return closeDB(a1)
	case host.SQLiteExecute:
		return exec(a1, false)
	case host.SQLiteQuery:
		return exec(a1, true)
	case host.SQLiteTransaction:
		return tx(a1)
	default:
		host.SetError(errors.New("zighost: unknown sqlite subop"))
		return ^uintptr(0)
	}
}

func open(specPtr uintptr) uintptr {
	spec := host.PtrTo[host.CSQLiteOpenSpec](specPtr)
	if spec == nil {
		host.SetError(errors.New("zighost: sqlite.open needs spec"))
		return ^uintptr(0)
	}
	path := host.CopyString(spec.PathPtr, spec.PathLen)
	db, err := plug.Open(context.Background(), path, plug.OpenOptions{ReadOnly: spec.ReadOnly != 0})
	if err != nil {
		host.SetError(err)
		return ^uintptr(0)
	}
	host.SetError(nil)
	id := nextID.Add(1)
	dbsMu.Lock()
	dbs[id] = db
	dbsMu.Unlock()
	return id
}

func closeDB(id uintptr) uintptr {
	dbsMu.Lock()
	db := dbs[id]
	delete(dbs, id)
	dbsMu.Unlock()
	if db != nil {
		_ = db.Close()
	}
	return 0
}

func get(id uintptr) *plug.DB {
	dbsMu.Lock()
	defer dbsMu.Unlock()
	return dbs[id]
}

func parseArgs(raw []byte) ([]any, error) {
	if len(raw) == 0 {
		return nil, nil
	}
	var args []any
	if err := json.Unmarshal(raw, &args); err != nil {
		return nil, err
	}
	return normalizeJSONArgs(args), nil
}

// normalizeJSONArgs turns json.Number into int64/float64 so SQLite binds cleanly.
func normalizeJSONArgs(args []any) []any {
	for i, v := range args {
		switch x := v.(type) {
		case json.Number:
			if n, err := x.Int64(); err == nil {
				args[i] = n
			} else if f, err := x.Float64(); err == nil {
				args[i] = f
			} else {
				args[i] = string(x)
			}
		case float64:
			// encoding/json uses float64 for numbers without UseNumber.
			if x == float64(int64(x)) {
				args[i] = int64(x)
			}
		}
	}
	return args
}

func exec(specPtr uintptr, query bool) uintptr {
	spec := host.PtrTo[host.CSQLiteExecSpec](specPtr)
	if spec == nil {
		host.SetError(errors.New("zighost: sqlite exec needs spec"))
		return ^uintptr(0)
	}
	db := get(spec.DBID)
	if db == nil {
		host.SetError(errors.New("zighost: unknown sqlite id"))
		return ^uintptr(0)
	}
	sql := host.CopyString(spec.SQLPtr, spec.SQLLen)
	args, err := parseArgs(host.CopyBytes(spec.ArgsPtr, spec.ArgsLen))
	if err != nil {
		host.SetError(err)
		return ^uintptr(0)
	}
	var raw []byte
	if query {
		rows, err := db.Query(context.Background(), sql, args...)
		if err != nil {
			host.SetError(err)
			return ^uintptr(0)
		}
		raw, err = json.Marshal(rows)
		if err != nil {
			host.SetError(err)
			return ^uintptr(0)
		}
	} else {
		res, err := db.Execute(context.Background(), sql, args...)
		if err != nil {
			host.SetError(err)
			return ^uintptr(0)
		}
		raw, err = json.Marshal(res)
		if err != nil {
			host.SetError(err)
			return ^uintptr(0)
		}
	}
	host.SetError(nil)
	return host.WriteBytesToOut(raw, spec.OutPtr, spec.OutCap)
}

type txStmt struct {
	SQL  string `json:"sql"`
	Args []any  `json:"args"`
}

func tx(specPtr uintptr) uintptr {
	spec := host.PtrTo[host.CSQLiteTxSpec](specPtr)
	if spec == nil {
		host.SetError(errors.New("zighost: sqlite.transaction needs spec"))
		return ^uintptr(0)
	}
	db := get(spec.DBID)
	if db == nil {
		host.SetError(errors.New("zighost: unknown sqlite id"))
		return ^uintptr(0)
	}
	var stmts []txStmt
	if err := json.Unmarshal(host.CopyBytes(spec.StmtsPtr, spec.StmtsLen), &stmts); err != nil {
		host.SetError(err)
		return ^uintptr(0)
	}
	list := make([]plug.Statement, len(stmts))
	for i, s := range stmts {
		list[i] = plug.Statement{SQL: s.SQL, Args: normalizeJSONArgs(s.Args)}
	}
	res, err := db.Transaction(context.Background(), list)
	if err != nil {
		host.SetError(err)
		return ^uintptr(0)
	}
	raw, err := json.Marshal(res)
	if err != nil {
		host.SetError(err)
		return ^uintptr(0)
	}
	host.SetError(nil)
	return host.WriteBytesToOut(raw, spec.OutPtr, spec.OutCap)
}
