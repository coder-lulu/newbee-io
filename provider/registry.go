package provider

import (
	"fmt"
	"sync"
)

type Registry struct {
	providers map[string]DiscoveryProvider
	mu        sync.RWMutex
}

var globalRegistry = NewRegistry()

func NewRegistry() *Registry {
	return &Registry{
		providers: make(map[string]DiscoveryProvider),
	}
}

func (r *Registry) Register(provider DiscoveryProvider) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	metadata := provider.GetMetadata()
	if _, exists := r.providers[metadata.ID]; exists {
		return fmt.Errorf("provider %s already registered", metadata.ID)
	}

	r.providers[metadata.ID] = provider
	return nil
}

func (r *Registry) GetProvider(id string) (DiscoveryProvider, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	provider, exists := r.providers[id]
	if !exists {
		return nil, fmt.Errorf("provider %s not found", id)
	}
	return provider, nil
}

func (r *Registry) ListProviders() []ProviderMetadata {
	r.mu.RLock()
	defer r.mu.RUnlock()

	metadata := make([]ProviderMetadata, 0, len(r.providers))
	for _, p := range r.providers {
		metadata = append(metadata, p.GetMetadata())
	}
	return metadata
}

func (r *Registry) Unregister(id string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.providers, id)
}

func Register(provider DiscoveryProvider) error {
	return globalRegistry.Register(provider)
}

func GetProvider(id string) (DiscoveryProvider, error) {
	return globalRegistry.GetProvider(id)
}

func ListProviders() []ProviderMetadata {
	return globalRegistry.ListProviders()
}
