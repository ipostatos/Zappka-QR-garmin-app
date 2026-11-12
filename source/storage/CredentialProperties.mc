import Toybox.Application;
import Toybox.Lang;

// Small SDK boundary so tests can inject read/write failures without real secrets.
class CredentialProperties {
    function getValue(key as String) as Object or Null {
        return Application.Properties.getValue(key);
    }

    function setValue(key as String, value as String) as Void {
        Application.Properties.setValue(key, value);
    }
}
