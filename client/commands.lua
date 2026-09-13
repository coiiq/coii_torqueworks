-- FiveM key mappings require paired internal commands. The leading +/- keeps
-- these bindings out of the normal player slash-command workflow.
RegisterCommand('+torqueworks_nitro', function()
    if TorqueWorksNitro and TorqueWorksNitro.press then TorqueWorksNitro.press() end
end, false)

RegisterCommand('-torqueworks_nitro', function()
    if TorqueWorksNitro and TorqueWorksNitro.release then TorqueWorksNitro.release() end
end, false)

RegisterKeyMapping('+torqueworks_nitro', 'Hold installed TorqueWorks nitrous', 'keyboard', 'LMENU')
