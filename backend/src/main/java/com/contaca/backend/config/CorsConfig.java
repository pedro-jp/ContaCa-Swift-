package com.contaca.backend.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.ViewControllerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class CorsConfig {

    @Bean
    public WebMvcConfigurer webMvcConfigurer() {
        return new WebMvcConfigurer() {
            @Override
            public void addCorsMappings(CorsRegistry registry) {
                registry.addMapping("/**")
                    .allowedOrigins("*")
                    .allowedMethods("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS")
                    .allowedHeaders("*");
            }

            @Override
            public void addViewControllers(ViewControllerRegistry registry) {
                // Redireciona / e /admin para /admin/ para carregamento correto dos assets estáticos
                registry.addRedirectViewController("/", "/admin/");
                registry.addRedirectViewController("/admin", "/admin/");
                registry.addViewController("/admin/").setViewName("forward:/admin/index.html");
                registry.addViewController("/privacy").setViewName("forward:/privacy.html");
                registry.addViewController("/privacidade").setViewName("forward:/privacy.html");
            }
        };
    }
}
