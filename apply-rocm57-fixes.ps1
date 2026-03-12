# ROCm 5.7 compatibility patch for llama.cpp
# Run from the root of your llama.cpp repo:
#   .\apply-rocm57-fixes.ps1

$root = Get-Location

function Patch-File {
    param($path, $pattern, $replacement, $checkPattern, $description)
    $full = Join-Path $root $path
    $content = Get-Content $full -Raw -Encoding UTF8
    if ($content -match $checkPattern) {
        Write-Host "[SKIP] Already patched: $description" -ForegroundColor Yellow
    } elseif ($content -match $pattern) {
        $content = [regex]::Replace($content, $pattern, $replacement)
        [System.IO.File]::WriteAllText($full, $content, [System.Text.Encoding]::UTF8)
        Write-Host "[OK] $description" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Could not find target in $path`: $description" -ForegroundColor Red
    }
}

Write-Host "`nApplying ROCm 5.7 fixes...`n"

# Fix 1: Disable ROCm >= 6.1 version check
Patch-File `
    "ggml/src/ggml-hip/CMakeLists.txt" `
    '(?m)^if \(\$\{hip_VERSION\} VERSION_LESS 6\.1\)\s*\r?\n\s*message\(FATAL_ERROR "At least ROCM/HIP V6\.1 is required"\)\s*\r?\n\s*endif\(\)' `
    '#if (${hip_VERSION} VERSION_LESS 6.1)
#    message(FATAL_ERROR "At least ROCM/HIP V6.1 is required")
#endif()' `
    '#if \(\$\{hip_VERSION\} VERSION_LESS 6\.1\)' `
    "Fix 1: Disable ROCm >= 6.1 version check"

# Fix 2: Add /FORCE:MULTIPLE linker flag for bfloat16 duplicate symbols
Patch-File `
    "ggml/src/ggml-hip/CMakeLists.txt" `
    '(?m)^(target_link_libraries\(ggml-hip )' `
    'target_link_options(ggml-hip PRIVATE -Xlinker /FORCE:MULTIPLE)
$1' `
    'target_link_options\(ggml-hip PRIVATE -Xlinker /FORCE:MULTIPLE\)' `
    "Fix 2: Add /FORCE:MULTIPLE linker flag"

# Fix 3a: cudaStreamWaitEvent join_events explicit 0 flag (line ~3478)
Patch-File `
    "ggml/src/ggml-cuda/ggml-cuda.cu" `
    'CUDA_CHECK\(cudaStreamWaitEvent\(cuda_ctx->stream\(\), concurrent_event->join_events\[i - 1\]\)\)' `
    'CUDA_CHECK(cudaStreamWaitEvent(cuda_ctx->stream(), concurrent_event->join_events[i - 1], 0))' `
    'cudaStreamWaitEvent\(cuda_ctx->stream\(\), concurrent_event->join_events\[i - 1\], 0\)' `
    "Fix 3a: cudaStreamWaitEvent join_events explicit 0 flag"

# Fix 3b: cudaStreamWaitEvent fork_event explicit 0 flag (line ~3503)
Patch-File `
    "ggml/src/ggml-cuda/ggml-cuda.cu" `
    'CUDA_CHECK\(cudaStreamWaitEvent\(stream, concurrent_event->fork_event\)\)' `
    'CUDA_CHECK(cudaStreamWaitEvent(stream, concurrent_event->fork_event, 0))' `
    'cudaStreamWaitEvent\(stream, concurrent_event->fork_event, 0\)' `
    "Fix 3b: cudaStreamWaitEvent fork_event explicit 0 flag"

# Fix 4: model_alias - already fixed upstream
Write-Host "[SKIP] Fix 4: model_alias already fixed upstream (line 820 uses *begin())" -ForegroundColor Yellow

# Fix 5: fim_sep_token -> fim_sub_token rename
Patch-File `
    "tools/cli/cli.cpp" `
    'fim_sep_token' `
    'fim_sub_token' `
    'fim_sub_token' `
    "Fix 5: fim_sep_token -> fim_sub_token rename"

Write-Host "`nDone. You can now run your cmake build.`n"