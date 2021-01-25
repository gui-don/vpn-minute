<?php

declare(strict_types=1);

namespace VPNMinute\Core\Exception;

use VPNMinute\Core\Exception\Main\UserException;

/**
 * Exception to use in case of errors in the configuration file.
 */
class ConfigurationException extends UserException
{
    public const MESSAGE_PREPEND = 'Invalid configuration file. ';

    public function __construct($message = '', $code = 0, \Throwable $previous = null)
    {
        parent::__construct(sprintf('%s%s', self::MESSAGE_PREPEND, $message), $code, $previous);
    }
}
