# ModelDispatch.psm1 - Unified model invocation for qwen3, kimi, and gemini
# Routes requests to appropriate model and handles response formatting

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:DefaultOllamaBase = 'http://127.0.0.1:11434'

function Invoke-OllamaModel {
    <#
    .SYNOPSIS
    Calls an Ollama model (local or online).

    .DESCRIPTION
    Supports both qwen3:latest (local heavy model) and kimi-k2-thinking (online fast model).

    .PARAMETER Model
    Model name (e.g., 'qwen3:latest', 'kimi-k2-thinking').

    .PARAMETER Prompt
    The prompt text.

    .PARAMETER SystemPrompt
    Optional system prompt.

    .PARAMETER Temperature
    Sampling temperature (default 0.7).

    .PARAMETER OllamaBaseUrl
    Ollama API base URL (default: http://127.0.0.1:11434).

    .PARAMETER Format
    Optional response format ('json' to request JSON output).

    .OUTPUTS
    Hashtable: @{ ok, response, error, model }
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Model,

        [Parameter(Mandatory)]
        [string]$Prompt,

        [string]$SystemPrompt = '',

        [double]$Temperature = 0.7,

        [string]$OllamaBaseUrl = $script:DefaultOllamaBase,

        [string]$Format = ''
    )

    try {
        $uri = "$OllamaBaseUrl/api/generate"

        $body = @{
            model = $Model
            prompt = $Prompt
            stream = $false
            options = @{
                temperature = $Temperature
            }
        }

        if ($SystemPrompt) {
            $body['system'] = $SystemPrompt
        }

        if ($Format -eq 'json') {
            $body['format'] = 'json'
        }

        $bodyJson = $body | ConvertTo-Json -Depth 4
        $response = Invoke-RestMethod -Method Post -Uri $uri -ContentType 'application/json' -Body $bodyJson -TimeoutSec 180

        if ($response.response) {
            return @{
                ok = $true
                response = [string]$response.response
                model = $Model
            }
        } else {
            return @{
                ok = $false
                error = 'No response field in Ollama output'
                model = $Model
            }
        }

    } catch {
        return @{
            ok = $false
            error = $_.Exception.Message
            model = $Model
        }
    }
}

function Invoke-GeminiModel {
    <#
    .SYNOPSIS
    Calls Google Gemini API for Evidence Card generation.

    .DESCRIPTION
    Uses the exact Evidence Card prompt (stored externally) and returns raw response.
    Does NOT modify the prompt in any way.

    .PARAMETER Prompt
    The evidence text to analyze.

    .PARAMETER ApiKey
    Gemini API key (should be loaded from secure config).

    .PARAMETER Model
    Gemini model name (default: 'gemini-1.5-pro').

    .OUTPUTS
    Hashtable: @{ ok, response, error, model }
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [Parameter(Mandatory)]
        [string]$ApiKey,

        [string]$Model = 'gemini-1.5-pro'
    )

    try {
        # Gemini API endpoint
        $uri = "https://generativelanguage.googleapis.com/v1/models/${Model}:generateContent?key=$ApiKey"

        $body = @{
            contents = @(
                @{
                    parts = @(
                        @{ text = $Prompt }
                    )
                }
            )
            generationConfig = @{
                temperature = 0.4
                topK = 32
                topP = 1
                maxOutputTokens = 8192
            }
        } | ConvertTo-Json -Depth 6

        $response = Invoke-RestMethod -Method Post -Uri $uri -ContentType 'application/json' -Body $body -TimeoutSec 180

        if ($response.candidates -and $response.candidates[0].content.parts) {
            $text = $response.candidates[0].content.parts[0].text
            return @{
                ok = $true
                response = $text
                model = $Model
            }
        } else {
            return @{
                ok = $false
                error = 'Unexpected Gemini response structure'
                model = $Model
            }
        }

    } catch {
        return @{
            ok = $false
            error = $_.Exception.Message
            model = $Model
        }
    }
}

function Invoke-Model {
    <#
    .SYNOPSIS
    Unified model dispatcher. Routes to Ollama (qwen3/kimi) or Gemini.

    .PARAMETER ModelName
    One of: 'qwen3', 'kimi', 'gemini'

    .PARAMETER Prompt
    The prompt text.

    .PARAMETER SystemPrompt
    Optional system prompt (Ollama only).

    .PARAMETER Temperature
    Sampling temperature.

    .PARAMETER Format
    Response format ('json' for structured output).

    .PARAMETER GeminiApiKey
    Required if ModelName = 'gemini'.

    .PARAMETER OllamaBaseUrl
    Ollama API base URL.

    .OUTPUTS
    Hashtable: @{ ok, response, error, model, model_type }
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet('qwen3', 'kimi', 'gemini')]
        [string]$ModelName,

        [Parameter(Mandatory)]
        [string]$Prompt,

        [string]$SystemPrompt = '',
        [double]$Temperature = 0.7,
        [string]$Format = '',
        [string]$GeminiApiKey = '',
        [string]$OllamaBaseUrl = $script:DefaultOllamaBase
    )

    Write-Host "[DISPATCH] Routing to model: $ModelName"

    switch ($ModelName) {
        'qwen3' {
            $result = Invoke-OllamaModel `
                -Model 'qwen3:latest' `
                -Prompt $Prompt `
                -SystemPrompt $SystemPrompt `
                -Temperature $Temperature `
                -Format $Format `
                -OllamaBaseUrl $OllamaBaseUrl

            $result['model_type'] = 'ollama_local'
            return $result
        }

        'kimi' {
            $result = Invoke-OllamaModel `
                -Model 'kimi-k2-thinking:latest' `
                -Prompt $Prompt `
                -SystemPrompt $SystemPrompt `
                -Temperature $Temperature `
                -Format $Format `
                -OllamaBaseUrl $OllamaBaseUrl

            $result['model_type'] = 'ollama_online'
            return $result
        }

        'gemini' {
            if (-not $GeminiApiKey) {
                return @{
                    ok = $false
                    error = 'GeminiApiKey required for gemini model'
                    model = 'gemini'
                    model_type = 'gemini'
                }
            }

            $result = Invoke-GeminiModel `
                -Prompt $Prompt `
                -ApiKey $GeminiApiKey `
                -Model 'gemini-1.5-pro'

            $result['model_type'] = 'gemini'
            return $result
        }

        Default {
            return @{
                ok = $false
                error = "Unknown model: $ModelName"
                model = $ModelName
                model_type = 'unknown'
            }
        }
    }
}

Export-ModuleMember -Function @(
    'Invoke-OllamaModel',
    'Invoke-GeminiModel',
    'Invoke-Model'
)
