package provider

import (
	"context"
	"time"
)

type FieldDefinition struct {
	Name        string                 `json:"name"`
	Label       string                 `json:"label"`
	DataType    string                 `json:"dataType"`
	Required    bool                   `json:"required"`
	Description string                 `json:"description"`
	Example     string                 `json:"example"`
	Metadata    map[string]interface{} `json:"metadata"`
}

type ParameterDefinition struct {
	Name         string                 `json:"name"`
	Label        string                 `json:"label"`
	Type         string                 `json:"type"`
	Required     bool                   `json:"required"`
	DefaultValue interface{}            `json:"defaultValue"`
	Placeholder  string                 `json:"placeholder"`
	Options      []string               `json:"options,omitempty"`
	Validation   *ValidationRule        `json:"validation,omitempty"`
	Description  string                 `json:"description"`
	Metadata     map[string]interface{} `json:"metadata,omitempty"`
}

type ValidationRule struct {
	Regex   string `json:"regex,omitempty"`
	MinLen  int    `json:"minLen,omitempty"`
	MaxLen  int    `json:"maxLen,omitempty"`
	Pattern string `json:"pattern,omitempty"`
}

type FieldMapping struct {
	SourceField string `json:"sourceField"`
	TargetField string `json:"targetField"`
	Transform   string `json:"transform,omitempty"`
}

type DiscoveryProvider interface {
	GetMetadata() ProviderMetadata

	GetParameterSchema() []ParameterDefinition

	GetFieldSchema() []FieldDefinition

	Initialize(config map[string]interface{}) error

	TestConnection(config map[string]interface{}) error

	Discover(ctx context.Context, config map[string]interface{}) ([]map[string]interface{}, error)

	ValidateMapping(mapping []FieldMapping) error
}

type ProviderMetadata struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Category    string `json:"category"`
	Description string `json:"description"`
	Version     string `json:"version"`
	Icon        string `json:"icon"`
}

type DiscoveryResult struct {
	TotalCount int                      `json:"totalCount"`
	Data       []map[string]interface{} `json:"data"`
	Error      string                   `json:"error,omitempty"`
	Duration   time.Duration            `json:"duration"`
}
