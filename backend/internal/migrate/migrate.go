package migrate

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

func Apply(ctx context.Context, db *pgxpool.Pool, path string) error {
	if path == "" {
		return fmt.Errorf("migrations path missing")
	}
	if err := ensureTable(ctx, db); err != nil {
		return err
	}
	files, err := readMigrationFiles(path)
	if err != nil {
		return err
	}
	applied, err := appliedVersions(ctx, db)
	if err != nil {
		return err
	}
	for _, file := range files {
		if applied[file] {
			continue
		}
		content, err := os.ReadFile(filepath.Join(path, file))
		if err != nil {
			return err
		}
		statements := splitStatements(string(content))
		if len(statements) == 0 {
			continue
		}
		mctx, cancel := context.WithTimeout(ctx, 30*time.Second)
		if err := runStatements(mctx, db, statements); err != nil {
			cancel()
			return fmt.Errorf("migration %s failed: %w", file, err)
		}
		cancel()
		if _, err := db.Exec(ctx, "insert into schema_migrations (version) values ($1)", file); err != nil {
			return err
		}
	}
	return nil
}

func ensureTable(ctx context.Context, db *pgxpool.Pool) error {
	_, err := db.Exec(ctx, `
		create table if not exists schema_migrations (
			version text primary key,
			applied_at timestamptz not null default now()
		)
	`)
	return err
}

func appliedVersions(ctx context.Context, db *pgxpool.Pool) (map[string]bool, error) {
	rows, err := db.Query(ctx, "select version from schema_migrations")
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	versions := make(map[string]bool)
	for rows.Next() {
		var v string
		if err := rows.Scan(&v); err != nil {
			return nil, err
		}
		versions[v] = true
	}
	return versions, rows.Err()
}

func readMigrationFiles(path string) ([]string, error) {
	entries, err := os.ReadDir(path)
	if err != nil {
		return nil, err
	}
	var files []string
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		if filepath.Ext(name) != ".sql" {
			continue
		}
		files = append(files, name)
	}
	sort.Strings(files)
	return files, nil
}

func splitStatements(sql string) []string {
	parts := strings.Split(sql, ";")
	var out []string
	for _, part := range parts {
		trimmed := strings.TrimSpace(part)
		if trimmed == "" {
			continue
		}
		out = append(out, trimmed)
	}
	return out
}

func runStatements(ctx context.Context, db *pgxpool.Pool, statements []string) error {
	for _, stmt := range statements {
		if _, err := db.Exec(ctx, stmt); err != nil {
			return err
		}
	}
	return nil
}
