<?php

declare(strict_types=1);

namespace VPNMinute\Core\Exception\Main;

/**
 * Exception to extend for developer errors. These exceptions are focused on bugs and runtime issues.
 */
abstract class DeveloperException extends \Exception
{
    public const ISSUE_TRACKER_URL = 'https://gitlab.com/gui-don/vpn-minute/-/issues';
    public const MESSAGE_WRAPPER = "\nOops! This is a BUG! \n The error message is:\n %s \nPlease report this issue at: %s.";

    public function __construct($message = '', $code = 0, \Throwable $previous = null)
    {
        parent::__construct(sprintf(self::MESSAGE_WRAPPER, $message, self::ISSUE_TRACKER_URL), $code, $previous);
    }
}
