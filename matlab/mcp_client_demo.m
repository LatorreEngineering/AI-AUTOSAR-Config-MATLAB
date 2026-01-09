%% AI-Assisted AUTOSAR Configuration Generator - MATLAB Client Demo
%
% This script demonstrates the integration between MATLAB, MCP (Model Context
% Protocol), and Large Language Models (LLMs) for automated AUTOSAR configuration
% generation.
%
% Prerequisites:
%   - MATLAB R2023b or later
%   - Text Analytics Toolbox
%   - MATLAB MCP HTTP Client (from File Exchange)
%   - Large Language Models (LLMs) with MATLAB add-on
%   - OpenAI API key set in environment variable OPENAI_API_KEY
%   - MCP Server running on http://localhost:5000
%
% Author: AI-Assisted AUTOSAR Project
% License: MIT

%% Clear workspace and command window
clear; clc; close all;

fprintf('=======================================================\n');
fprintf('AI-Assisted AUTOSAR Configuration Generator\n');
fprintf('MATLAB Client Demo\n');
fprintf('=======================================================\n\n');

%% Configuration
MCP_SERVER_URL = 'http://localhost:5000';
LLM_MODEL = 'gpt-4';  % Can also use 'gpt-4-turbo' or 'gpt-3.5-turbo'

%% Step 1: Check prerequisites
fprintf('Step 1: Checking prerequisites...\n');

% Check for OpenAI API key
apiKey = getenv('OPENAI_API_KEY');
if isempty(apiKey)
    error(['OpenAI API key not found. Please set OPENAI_API_KEY environment variable.\n', ...
           'Example: setenv(''OPENAI_API_KEY'', ''sk-your-key-here'')']);
end
fprintf('  ✓ OpenAI API key found\n');

% Check MCP server connectivity
try
    response = webread([MCP_SERVER_URL, '/']);
    fprintf('  ✓ MCP Server is running (%s)\n', response.status);
catch ME
    error(['Cannot connect to MCP server at %s\n', ...
           'Please start the server: python server/app.py'], MCP_SERVER_URL);
end

fprintf('\n');

%% Step 2: Load LLM prompt template
fprintf('Step 2: Loading LLM prompt template...\n');

% Read the prompt template
templatePath = fullfile(fileparts(mfilename('fullpath')), 'llm_prompt_template.txt');
if ~isfile(templatePath)
    error('Prompt template not found at: %s', templatePath);
end

systemPrompt = fileread(templatePath);
fprintf('  ✓ Loaded system prompt (%d characters)\n', length(systemPrompt));
fprintf('\n');

%% Step 3: Initialize MCP Client
fprintf('Step 3: Initializing MCP HTTP Client...\n');

try
    % Create MCP client using mcpHTTPClient function
    % This connects to the MCP server and fetches available tools
    client = mcpHTTPClient(MCP_SERVER_URL);
    
    % Get available tools from server
    serverTools = client.ServerTools;
    
    fprintf('  ✓ Connected to MCP server\n');
    fprintf('  ✓ Found %d available tools:\n', length(serverTools));
    for i = 1:length(serverTools)
        fprintf('    - %s: %s\n', serverTools{i}.name, ...
                truncateString(serverTools{i}.description, 60));
    end
catch ME
    error('Failed to initialize MCP client: %s', ME.message);
end

fprintf('\n');

%% Step 4: Initialize OpenAI Chat with tools
fprintf('Step 4: Initializing LLM agent with MCP tools...\n');

try
    % Convert MCP server tools to openAIFunction objects
    % This makes the tools available to the LLM for function calling
    mcpFunctions = openAIFunction(serverTools);
    
    % Create OpenAI Chat object with function calling enabled
    chat = openAIChat(LLM_MODEL, ...
        'SystemPrompt', systemPrompt, ...
        'Tools', mcpFunctions, ...
        'Temperature', 0.7);
    
    fprintf('  ✓ LLM agent initialized (%s)\n', LLM_MODEL);
    fprintf('  ✓ Registered %d tools with LLM\n', length(serverTools));
catch ME
    error('Failed to initialize LLM: %s', ME.message);
end

fprintf('\n');

%% Step 5: Interactive demo - Example queries
fprintf('=======================================================\n');
fprintf('Running Example Queries\n');
fprintf('=======================================================\n\n');

% Define example queries
exampleQueries = {
    'Configure a CAN interface for a powertrain ECU operating at 500 kbps with extended error handling and 8 message objects for engine control', ...
    'Set up NvM blocks for fault logging with 100 fault codes, immediate write for critical faults, and wear-leveling', ...
    'Create a CAN configuration for a body control module at 250 kbps with 16 message objects and wakeup support'
};

% Process each example query
for queryIdx = 1:length(exampleQueries)
    userQuery = exampleQueries{queryIdx};
    
    fprintf('Query %d:\n"%s"\n\n', queryIdx, userQuery);
    fprintf('Processing with LLM agent...\n');
    
    try
        % Generate response from LLM
        % The LLM will decide which tools to call based on the query
        messages = {struct('role', 'user', 'content', userQuery)};
        [response, streamedText] = generate(chat, messages);
        
        % Check if LLM wants to call tools
        if isfield(response, 'tool_calls') && ~isempty(response.tool_calls)
            fprintf('  → LLM requested tool calls\n');
            
            % Execute each tool call
            for toolIdx = 1:length(response.tool_calls)
                toolCall = response.tool_calls(toolIdx);
                toolName = toolCall.function.name;
                
                fprintf('  → Calling tool: %s\n', toolName);
                
                % Execute the tool via MCP client
                % The callTool function handles the HTTP request to the server
                toolResult = callTool(client, toolCall.function);
                
                fprintf('  ✓ Tool execution completed\n');
                
                % Parse the result
                if isfield(toolResult, 'success') && toolResult.success
                    fprintf('  → Module: %s\n', toolResult.module);
                    fprintf('  → ARXML length: %d characters\n', length(toolResult.arxml));
                    
                    % Save output to file
                    outputFilename = sprintf('output_query_%d_%s.arxml', ...
                                           queryIdx, toolResult.module);
                    outputPath = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
                                        'examples', outputFilename);
                    
                    % Write ARXML to file
                    fid = fopen(outputPath, 'w', 'n', 'UTF-8');
                    fprintf(fid, '%s', toolResult.arxml);
                    fclose(fid);
                    
                    fprintf('  → Saved to: %s\n', outputPath);
                else
                    fprintf('  ✗ Tool execution failed\n');
                end
            end
        else
            % LLM responded without tool calls
            fprintf('  → LLM response (no tool calls):\n');
            fprintf('  %s\n', streamedText);
        end
        
    catch ME
        fprintf('  ✗ Error processing query: %s\n', ME.message);
    end
    
    fprintf('\n');
    fprintf('-------------------------------------------------------\n\n');
end

%% Step 6: Interactive mode (optional)
fprintf('=======================================================\n');
fprintf('Interactive Mode\n');
fprintf('=======================================================\n\n');
fprintf('You can now enter your own queries.\n');
fprintf('Type ''exit'' to quit.\n\n');

% Initialize conversation history
conversationHistory = {};

while true
    userInput = input('Enter your AUTOSAR configuration request: ', 's');
    
    if strcmpi(userInput, 'exit')
        fprintf('\nExiting interactive mode.\n');
        break;
    end
    
    if isempty(strtrim(userInput))
        continue;
    end
    
    fprintf('\nProcessing your request...\n');
    
    try
        % Add user message to conversation
        conversationHistory{end+1} = struct('role', 'user', 'content', userInput);
        
        % Generate response
        [response, streamedText] = generate(chat, conversationHistory);
        
        % Handle tool calls
        if isfield(response, 'tool_calls') && ~isempty(response.tool_calls)
            fprintf('Executing tool calls...\n');
            
            for toolIdx = 1:length(response.tool_calls)
                toolCall = response.tool_calls(toolIdx);
                fprintf('  → %s\n', toolCall.function.name);
                
                toolResult = callTool(client, toolCall.function);
                
                if isfield(toolResult, 'success') && toolResult.success
                    fprintf('  ✓ Success: %s configuration generated\n', toolResult.module);
                    
                    % Display preview
                    arxmlPreview = toolResult.arxml;
                    if length(arxmlPreview) > 500
                        arxmlPreview = [arxmlPreview(1:500), '...'];
                    end
                    fprintf('\nARXML Preview:\n%s\n\n', arxmlPreview);
                else
                    fprintf('  ✗ Error in tool execution\n\n');
                end
            end
        else
            fprintf('LLM Response:\n%s\n\n', streamedText);
        end
        
        % Add assistant response to history
        conversationHistory{end+1} = struct('role', 'assistant', 'content', streamedText);
        
    catch ME
        fprintf('✗ Error: %s\n\n', ME.message);
    end
end

fprintf('\n=======================================================\n');
fprintf('Demo completed. Thank you for using the AI-Assisted\n');
fprintf('AUTOSAR Configuration Generator!\n');
fprintf('=======================================================\n');

%% Helper Functions

function truncated = truncateString(str, maxLen)
    % Truncate string to maximum length with ellipsis
    if length(str) > maxLen
        truncated = [str(1:maxLen-3), '...'];
    else
        truncated = str;
    end
end
