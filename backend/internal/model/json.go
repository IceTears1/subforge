package model

import (
	"database/sql/driver"
	"encoding/json"
	"fmt"
)

// JSON is a custom type for JSONB columns that doesn't require gorm.io/datatypes
type JSON []byte

// Value implements the driver.Valuer interface
func (j JSON) Value() (driver.Value, error) {
	if j == nil {
		return nil, nil
	}
	return string(j), nil
}

// Scan implements the sql.Scanner interface
func (j *JSON) Scan(value interface{}) error {
	if value == nil {
		*j = []byte("[]")
		return nil
	}
	switch v := value.(type) {
	case []byte:
		*j = make([]byte, len(v))
		copy(*j, v)
	case string:
		*j = []byte(v)
	default:
		return fmt.Errorf("cannot scan %T into JSON", value)
	}
	return nil
}

// MarshalJSON implements json.Marshaler
func (j JSON) MarshalJSON() ([]byte, error) {
	if j == nil {
		return []byte("null"), nil
	}
	return j, nil
}

// UnmarshalJSON implements json.Unmarshaler
func (j *JSON) UnmarshalJSON(data []byte) error {
	if j == nil {
		return nil
	}
	*j = make([]byte, len(data))
	copy(*j, data)
	return nil
}

// ToSlice converts JSON to a slice of strings
func (j JSON) ToSlice() ([]string, error) {
	var result []string
	if err := json.Unmarshal(j, &result); err != nil {
		return nil, err
	}
	return result, nil
}

// ToStringSlice is a helper to convert JSON to []string
func ToStringSlice(j JSON) []string {
	result, err := j.ToSlice()
	if err != nil {
		return []string{}
	}
	return result
}
