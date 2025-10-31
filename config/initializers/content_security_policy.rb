# Be sure to restart your server when you modify this file.

# SECURITY: Content Security Policy (CSP)
#
# CSP is a defense-in-depth security layer that helps detect and mitigate:
# - Cross-Site Scripting (XSS) attacks
# - Data injection attacks
# - Clickjacking attacks
#
# This configuration is part of the golden_deployment template and should be
# copied to all new Rails apps for consistent security posture.
#
# See: https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    # Only load resources from our own domain and HTTPS sources
    policy.default_src :self, :https

    # Allow fonts from our domain, HTTPS, and data URIs (for inline fonts)
    policy.font_src    :self, :https, :data

    # Allow images from our domain, HTTPS, and data URIs (for inline images)
    policy.img_src     :self, :https, :data

    # Block all object/embed/applet tags (Flash, Java, etc.) - not needed in modern apps
    policy.object_src  :none

    # Scripts: Allow from self and use nonces for inline scripts
    # Nonces prevent inline script injection while allowing our own inline scripts
    policy.script_src  :self

    # Styles: Allow from self and use nonces for inline styles
    policy.style_src   :self, :unsafe_inline  # unsafe_inline needed for <style> tags in views

    # Prevent framing our app (clickjacking protection)
    policy.frame_ancestors :none
  end

  # Generate session nonces for permitted inline scripts and styles
  # This allows our own inline code while blocking injected code
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w(script-src)

  # For development/testing: Start with report-only mode, then enforce
  # Uncomment to report violations without blocking (good for testing)
  # config.content_security_policy_report_only = true
end
