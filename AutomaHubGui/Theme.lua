--!strict

local Theme = {}

function Theme.Init(WindUI: any, Tab: any): any
    Tab:Section({
        Title = "Themes are limited in WindUI.",
    })
    Tab:Section({
        Title = "Crimson theme is set via Accent colors natively.",
    })
    
    return nil
end

return Theme
