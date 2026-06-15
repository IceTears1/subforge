package cache

import (
	"testing"
	"time"
)

func TestCacheSetGet(t *testing.T) {
	c := New(10)

	c.Set("key1", "value1", time.Minute)

	val, etag, ok := c.Get("key1")
	if !ok {
		t.Fatal("expected cache hit")
	}
	if val != "value1" {
		t.Errorf("got %s, want value1", val)
	}
	if etag == "" {
		t.Error("etag should not be empty")
	}
}

func TestCacheMiss(t *testing.T) {
	c := New(10)

	_, _, ok := c.Get("nonexistent")
	if ok {
		t.Error("expected cache miss")
	}
}

func TestCacheExpiry(t *testing.T) {
	c := New(10)

	c.Set("key1", "value1", 50*time.Millisecond)

	// Should hit
	_, _, ok := c.Get("key1")
	if !ok {
		t.Fatal("expected cache hit")
	}

	// Wait for expiry
	time.Sleep(100 * time.Millisecond)

	_, _, ok = c.Get("key1")
	if ok {
		t.Error("expected cache miss after expiry")
	}
}

func TestCacheDelete(t *testing.T) {
	c := New(10)

	c.Set("key1", "value1", time.Minute)
	c.Delete("key1")

	_, _, ok := c.Get("key1")
	if ok {
		t.Error("expected cache miss after delete")
	}
}

func TestCacheEviction(t *testing.T) {
	c := New(2) // max 2 items

	c.Set("key1", "value1", time.Minute)
	c.Set("key2", "value2", time.Minute)
	c.Set("key3", "value3", time.Minute) // should evict oldest

	// key1 should be evicted
	_, _, ok := c.Get("key1")
	if ok {
		t.Error("key1 should have been evicted")
	}

	// key2 and key3 should exist
	_, _, ok = c.Get("key2")
	if !ok {
		t.Error("key2 should exist")
	}
	_, _, ok = c.Get("key3")
	if !ok {
		t.Error("key3 should exist")
	}
}

func TestCacheETagConsistency(t *testing.T) {
	c := New(10)

	c.Set("key1", "value1", time.Minute)

	_, etag1, _ := c.Get("key1")
	_, etag2, _ := c.Get("key1")

	if etag1 != etag2 {
		t.Errorf("etags should be consistent: %s != %s", etag1, etag2)
	}
}
