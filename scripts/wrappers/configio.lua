local ConfigIO = {}

local GameEnv = nil

function ConfigIO.Initialize(game_env)
    GameEnv = game_env
end

function ConfigIO.Save(persist_key, config_state)
    if not GameEnv then return end
    local str = GameEnv.json.encode(config_state.Settings)
    GameEnv.TheSim:SetPersistentString(persist_key, str, false)
end

function ConfigIO.Load(persist_key, config_state, on_loaded_callback)
    if not GameEnv then return end
    GameEnv.TheSim:GetPersistentString(persist_key, function(load_success, str)
        if load_success and str then
            local success, data = GameEnv.pcall(GameEnv.json.decode, str)
            if success and GameEnv.type(data) == "table" then
                for k, v in pairs(data) do
                    config_state.UpdateSetting(k, v)
                end
            end
        end
        if on_loaded_callback then
            on_loaded_callback()
        end
    end)
end

return ConfigIO