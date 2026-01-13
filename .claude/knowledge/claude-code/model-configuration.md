# Model Configuration Quick Reference

## TL;DR

This project uses **Opus 4.5** by default for all operations (planning and execution).

**Override commands:**
```bash
/model sonnet     # Switch to Sonnet (temporary)
/model opusplan   # Switch to OpusPlan (temporary)
/model haiku      # Switch to Haiku (temporary)
```

**Persistent override** (add to `.envrc`):
```bash
export ANTHROPIC_MODEL="opusplan"  # Or "sonnet" for faster execution
```

## Model Comparison

| Model | Best For | Speed | Cost | Context |
|-------|----------|-------|------|---------|
| `opus` | **Default** - Maximum reasoning for all operations | Slower | Highest (15x) | Standard |
| `opusplan` | Complex planning + fast execution (hybrid) | Mixed | Balanced | Standard |
| `sonnet` | General development, bug fixes | Fast | Lower | Standard |
| `haiku` | Simple tasks, file operations | Fastest | Lowest | Standard |
| `sonnet[1m]` | Very large codebases | Fast | Lower | 1M tokens |

## When to Use What

### Opus (Default) ⭐
- ✅ All development workflows
- ✅ Maximum reasoning and code quality
- ✅ Critical architecture decisions
- ✅ Complex refactoring and algorithm design
- ✅ Best quality code generation

### OpusPlan (Override for Speed)
- ⚡ Need faster execution while maintaining planning quality
- 💰 Budget-conscious development
- 🔄 Mixed planning and coding tasks

### Sonnet
- 🐛 Quick bug fixes
- 📝 Straightforward implementations
- ⚡ Speed over deep reasoning

### Haiku
- 📄 Simple file operations
- 👀 Basic code reviews (no changes)
- 🏃 Maximum speed needed

## Override Priority

Settings are applied in this order (highest priority first):

1. **Session command**: `/model <name>` (temporary)
2. **Environment variable**: `ANTHROPIC_MODEL` in `.envrc` (local default)
3. **Team setting**: `.claude/settings.json` (project default = `opus`)
4. **User setting**: `~/.claude/settings.json` (global default)
5. **System default**: Sonnet

## Configuration Examples

### Quick Bug Fix (Speed Override)
```bash
/model sonnet
# Make the fix, then return to default
/model opus
```

### Balanced Development (Cost Override)
```bash
# Use hybrid approach for speed
/model opusplan
# Or stay on Sonnet for straightforward work
/model sonnet
```

### Cost-Conscious Development
Add to `.envrc`:
```bash
export ANTHROPIC_MODEL="opusplan"  # Hybrid approach
# or
export ANTHROPIC_MODEL="sonnet"    # Fast execution, lower cost
```
Default Opus provides maximum quality - override only if speed/cost is a concern.

## Cost Awareness

Approximate relative costs:
- **Haiku**: 1x (baseline)
- **Sonnet**: 3x
- **OpusPlan**: ~4-6x (depends on planning/execution ratio)
- **Opus**: 15x (default)

**Note**: This project prioritizes quality over cost. If cost is a concern, override to `opusplan` or `sonnet` in your local `.envrc`.

## Troubleshooting

**Model not changing?**
1. Check current model in status line
2. Try explicit switch: `/model opus`
3. Check environment: `echo $ANTHROPIC_MODEL`
4. Restart session if needed

**Want to reduce costs?**
1. Check which model is active (should be `opus` by default)
2. Override to `opusplan` or `sonnet` in your `.envrc`
3. Use `/model opusplan` for temporary speed boost

## Related Documentation

- **Settings Guide**: `.claude/docs/SETTINGS_GUIDE.md` - Complete settings documentation
- **Official Docs**: [Model Configuration](https://code.claude.com/docs/en/model-config)
- **Environment Setup**: `.envrc.example` - Model override examples

---

**Why Opus?** Maximum reasoning power for all operations ensures the highest quality code generation, analysis, and decision-making. Override to `opusplan` or `sonnet` if speed or cost is a priority for your specific workflow.
