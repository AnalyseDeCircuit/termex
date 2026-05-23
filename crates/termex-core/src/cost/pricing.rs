//! Per-model pricing table — used by both the estimator (before the
//! task runs) and the recorder (after MCP `usage` events arrive).
//!
//! Users can override individual entries via Settings. The table is
//! pure data + a calculate() helper — no I/O.

use std::collections::HashMap;

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ModelPrice {
    /// USD per 1k input tokens.
    pub input_per_1k: f64,
    /// USD per 1k output tokens.
    pub output_per_1k: f64,
}

#[derive(Debug, Clone)]
pub struct ModelPricing {
    table: HashMap<String, ModelPrice>,
    /// Fallback applied when the model name doesn't match any known
    /// entry. Defaults to claude-3.5-sonnet pricing on the
    /// assumption that "unknown model" usually = "newer model from a
    /// major vendor", so a mid-tier rate is a reasonable estimate.
    fallback: ModelPrice,
}

impl Default for ModelPricing {
    fn default() -> Self {
        let mut t = HashMap::new();
        // 2026 H1 list prices — easy to refresh.
        let sonnet = ModelPrice {
            input_per_1k: 0.003,
            output_per_1k: 0.015,
        };
        t.insert("claude-3.5-sonnet".into(), sonnet);
        t.insert("claude-3-haiku".into(),
            ModelPrice {
                input_per_1k: 0.00025,
                output_per_1k: 0.00125,
            },
        );
        t.insert("gpt-4o".into(),
            ModelPrice {
                input_per_1k: 0.0025,
                output_per_1k: 0.010,
            },
        );
        t.insert("gpt-4o-mini".into(),
            ModelPrice {
                input_per_1k: 0.00015,
                output_per_1k: 0.00060,
            },
        );
        t.insert("o1".into(),
            ModelPrice {
                input_per_1k: 0.015,
                output_per_1k: 0.060,
            },
        );
        t.insert("o1-mini".into(),
            ModelPrice {
                input_per_1k: 0.003,
                output_per_1k: 0.012,
            },
        );
        Self {
            table: t,
            fallback: sonnet,
        }
    }
}

impl ModelPricing {
    /// Apply a user-supplied override. Replaces any existing entry
    /// for that model.
    pub fn set(&mut self, model: impl Into<String>, price: ModelPrice) {
        self.table.insert(model.into(), price);
    }

    /// Look up a model's pricing, or return the fallback rate.
    pub fn price_for(&self, model: &str) -> ModelPrice {
        self.table.get(model).copied().unwrap_or(self.fallback)
    }

    /// True iff the table has an explicit entry for `model`.
    pub fn knows(&self, model: &str) -> bool {
        self.table.contains_key(model)
    }

    /// Compute the cost in USD given input/output token counts.
    /// Negative tokens are clamped to 0 so a misreporting CLI can't
    /// generate a negative bill.
    pub fn calculate(&self, model: &str, input_tokens: u64, output_tokens: u64) -> f64 {
        let p = self.price_for(model);
        let inp = (input_tokens as f64) / 1000.0 * p.input_per_1k;
        let out = (output_tokens as f64) / 1000.0 * p.output_per_1k;
        round_cents(inp + out)
    }
}

/// Round to 4 decimal places — enough precision for $0.0001 token
/// dust, more than enough for display rounding ($0.12).
fn round_cents(v: f64) -> f64 {
    (v * 10_000.0).round() / 10_000.0
}
