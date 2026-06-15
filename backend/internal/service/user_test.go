package service

import (
	"testing"
)

func TestValidatePassword(t *testing.T) {
	tests := []struct {
		name    string
		pass    string
		wantErr bool
	}{
		{"valid", "Abcdef123", false},
		{"too short", "Abc12", true},
		{"no uppercase", "abcdef123", true},
		{"no lowercase", "ABCDEF123", true},
		{"no digit", "Abcdefghi", true},
		{"exactly 8", "Abcde123", false},
		{"long", "Abcdefghijklmnop123456789", false},
		{"empty", "", true},
		{"only spaces", "        ", true},
		{"special chars", "Abc123!@#", false},
		{"unicode", "Abc123中文", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := ValidatePassword(tt.pass)
			if (err != nil) != tt.wantErr {
				t.Errorf("ValidatePassword(%q) error = %v, wantErr %v", tt.pass, err, tt.wantErr)
			}
		})
	}
}
