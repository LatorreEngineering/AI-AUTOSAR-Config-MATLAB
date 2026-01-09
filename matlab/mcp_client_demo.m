%% AI-Assisted AUTOSAR Configuration Generator - MATLAB Client Demo
%
% This script demonstrates the integration between MATLAB, MCP (Model Context
% Protocol), and Large Language Models (LLMs) for automated AUTOSAR configuration
% generation.
%
% Prerequisites:
%   - MATLAB R2023b or later
%   - Text Analytics Toolbox
%   - MATLAB Support for MCP
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

%% Step 3: Fetch available tools from MCP server
fprintf('Step 3: Fetching available tools from MCP server...\n');

try
    toolsResponse = webread([MCP_SERVER_URL, '/tools']);
    availableTools = toolsResponse.tools;
    fprintf('  ✓ Found %d available tools:\n', length(availableTools));
    for i = 1:length(availableTools)
        fprintf('    - %s\n', availableTools(i).name);
    end
catch ME
    error('Failed to fetch tools: %s', ME.message);
end

fprintf('\n');

%% Step 4: Initialize OpenAI Chat with tools
fprintf('Step 4: Initializing LLM agent...\n');

% Convert MATLAB struct array to cell array of structs for OpenAI
toolDefinitions = cell(1, length(availableTools));
for i = 1:length(availableTools)
    tool = availableTools(i);
    toolDefinitions{i} = struct(...
        'type', 'function', ...
        'function', struct(...
            'name', tool.name, ...
            'description', tool.description, ...
            'parameters', tool.inputSchema ...
        ) ...
    );
end

% Create OpenAI Chat object
% Note: This requires the OpenAI API credentials to be configured
% You may need to use openAIChat differently based on your MATLAB version
fprintf('  ✓ LLM agent initialized with %d tools\n', length(toolDefinitions));
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
    fprintf('Processing...\n');
    
    % Call the LLM with function calling
    % Note: Actual implementation depends on your MATLAB OpenAI integration
    % This is a simplified demonstration
    
    % Parse the query and determine which tool to call
    % In a full implementation, the LLM would do this automatically
    toolCall = parseQueryForToolCall(userQuery, availableTools);
    
    if ~isempty(toolCall)
        fprintf('  → Calling tool: %s\n', toolCall.name);
        fprintf('  → Parameters:\n');
        disp(toolCall.parameters);
        
        % Execute the tool call via MCP server
        result = executeMCPTool(MCP_SERVER_URL, toolCall.name, toolCall.parameters);
        
        if result.success
            fprintf('  ✓ Configuration generated successfully\n');
            fprintf('  → Module: %s\n', result.module);
            fprintf('  → ARXML length: %d characters\n', length(result.arxml));
            
            % Save output to file
            outputFilename = sprintf('output_query_%d_%s.arxml', queryIdx, result.module);
            outputPath = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
                                'examples', outputFilename);
            
            % Write ARXML to file
            fid = fopen(outputPath, 'w', 'n', 'UTF-8');
            fprintf(fid, '%s', result.arxml);
            fclose(fid);
            
            fprintf('  → Saved to: %s\n', outputPath);
        else
            fprintf('  ✗ Configuration generation failed\n');
            fprintf('  → Error: %s\n', result.error);
        end
    else
        fprintf('  ✗ Could not determine appropriate tool for query\n');
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
    
    % Parse and execute
    toolCall = parseQueryForToolCall(userInput, availableTools);
    
    if ~isempty(toolCall)
        result = executeMCPTool(MCP_SERVER_URL, toolCall.name, toolCall.parameters);
        
        if result.success
            fprintf('✓ Configuration generated successfully!\n');
            fprintf('Module: %s\n', result.module);
            
            % Display first 500 characters of ARXML
            arxmlPreview = result.arxml;
            if length(arxmlPreview) > 500
                arxmlPreview = [arxmlPreview(1:500), '...'];
            end
            fprintf('\nARXML Preview:\n%s\n\n', arxmlPreview);
        else
            fprintf('✗ Error: %s\n\n', result.error);
        end
    else
        fprintf('✗ Could not determine appropriate tool for your request.\n\n');
    end
end

fprintf('\n=======================================================\n');
fprintf('Demo completed. Thank you for using the AI-Assisted\n');
fprintf('AUTOSAR Configuration Generator!\n');
fprintf('=======================================================\n');

%% Helper Functions

function toolCall = parseQueryForToolCall(query, availableTools)
    % Simple rule-based parsing (in production, LLM would handle this)
    % This function demonstrates the concept; actual implementation would
    % use LLM for intelligent parsing
    
    toolCall = struct();
    queryLower = lower(query);
    
    % Check for CAN-related query
    if contains(queryLower, 'can') && contains(queryLower, 'configure')
        toolCall.name = 'generateCanConfig';
        
        % Extract parameters
        params = struct();
        
        % ECU type
        if contains(queryLower, 'powertrain')
            params.ecuType = 'powertrain';
        elseif contains(queryLower, 'body')
            params.ecuType = 'body';
        elseif contains(queryLower, 'chassis')
            params.ecuType = 'chassis';
        else
            params.ecuType = 'powertrain';  % Default
        end
        
        % Baudrate
        baudrates = [125, 250, 500, 1000];
        for br = baudrates
            if contains(queryLower, sprintf('%d', br))
                params.baudrate = br;
                break;
            end
        end
        if ~isfield(params, 'baudrate')
            params.baudrate = 500;  % Default
        end
        
        % Message objects
        msgObjMatch = regexp(queryLower, '(\d+)\s+message', 'tokens');
        if ~isempty(msgObjMatch)
            params.messageObjects = str2double(msgObjMatch{1}{1});
        else
            params.messageObjects = 8;  % Default
        end
        
        % Error handling
        params.errorHandling = contains(queryLower, 'error');
        
        % Wakeup support
        params.wakeupSupport = contains(queryLower, 'wakeup');
        
        toolCall.parameters = params;
        
    % Check for NvM-related query
    elseif contains(queryLower, 'nvm') || contains(queryLower, 'fault')
        toolCall.name = 'generateNvmConfig';
        
        params = struct();
        
        % Block count
        blockMatch = regexp(queryLower, '(\d+)\s+(?:fault|block)', 'tokens');
        if ~isempty(blockMatch)
            params.blockCount = str2double(blockMatch{1}{1});
        else
            params.blockCount = 10;  % Default
        end
        
        % Block size (simplified - would be calculated based on requirements)
        params.blockSize = 256;
        
        % Write strategy
        if contains(queryLower, 'immediate')
            params.writeStrategy = 'immediate';
        elseif contains(queryLower, 'deferred')
            params.writeStrategy = 'deferred';
        else
            params.writeStrategy = 'immediate';  % Default for fault logging
        end
        
        % Features
        params.crcProtection = true;  % Always enabled for fault data
        params.redundancy = contains(queryLower, 'redundan');
        params.wearLeveling = contains(queryLower, 'wear');
        
        toolCall.parameters = params;
        
    else
        % No matching tool found
        toolCall = [];
    end
end

function result = executeMCPTool(serverUrl, toolName, parameters)
    % Execute a tool call on the MCP server
    
    try
        % Prepare request
        url = sprintf('%s/%s', serverUrl, toolName);
        options = weboptions('MediaType', 'application/json', ...
                            'RequestMethod', 'post', ...
                            'Timeout', 30);
        
        % Make request
        response = webwrite(url, parameters, options);
        
        % Return structured result
        result = struct();
        result.success = response.success;
        if response.success
            result.module = response.module;
            result.arxml = response.arxml;
            result.parameters = response.parameters;
        else
            result.error = 'Unknown error';
        end
        
    catch ME
        % Handle errors
        result = struct();
        result.success = false;
        result.error = ME.message;
    end
end
