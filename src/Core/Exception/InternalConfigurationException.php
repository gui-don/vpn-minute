<?php

declare(strict_types=1);

namespace VPNMinute\Core\Exception;

use VPNMinute\Core\Exception\Main\DeveloperException;

/**
 * Exception to use in case of incorrect runtime configuration due to a missing feature or an unattended code execution.
 */
class InternalConfigurationException extends DeveloperException
{
    public const MESSAGE_PREPEND = 'Internal configuration error. ';

    public function __construct($message = '', $code = 0, \Throwable $previous = null)
    {
        parent::__construct(sprintf('%s%s', self::MESSAGE_PREPEND, $message), $code, $previous);
    }
}
